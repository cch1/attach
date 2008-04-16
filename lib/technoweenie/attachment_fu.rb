module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    @@default_processors = %w(ImageScience Rmagick MiniMagick)
    @@tempfile_path      = File.join(RAILS_ROOT, 'tmp', 'attachment_fu')
    @@thumb_content_types = ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg', 'image/bmp']
    @@program_content_types = ['text/html']
    @@icon_content_types = @@program_content_types + ['application/xls']
    @@content_types = @@thumb_content_types + @@icon_content_types
    mattr_reader :content_types, :thumb_content_types, :icon_content_types, :program_content_types
    mattr_reader :tempfile_path, :default_processors
    mattr_writer :tempfile_path

    class ThumbnailError < StandardError;  end
    class AttachmentError < StandardError; end

    module ActMethods
      # Options: 
      # *  <tt>:content_type</tt> - Allowed content types.  Allows all by default.  Use :image to allow all standard image types.
      # *  <tt>:min_size</tt> - Minimum size allowed.  1 byte is the default.
      # *  <tt>:max_size</tt> - Maximum size allowed.  1.megabyte is the default.
      # *  <tt>:size</tt> - Range of sizes allowed.  (1..1.megabyte) is the default.  This overrides the :min_size and :max_size options.
      # *  <tt>:resize_to</tt> - Used by RMagick to resize images.  Pass either an array of width/height, or a geometry string.
      # *  <tt>:thumbnails</tt> - Specifies a set of thumbnails to generate.  This accepts a hash of filename suffixes and RMagick resizing options.
      # *  <tt>:thumbnail_class</tt> - Set what class to use for thumbnails.  This attachment class is used by default.
      # *  <tt>:path_prefix</tt> - path to store the uploaded files.  Uses public/#{table_name} by default for the filesystem, and just #{table_name}
      #      for the S3 backend.  Setting this sets the :storage to :file_system.
      # *  <tt>:storage</tt> - Use :file_system to specify the attachment data is stored with the file system.  Defaults to :db_system.
      #
      # Examples:
      #   has_attachment :max_size => 1.kilobyte
      #   has_attachment :size => 1.megabyte..2.megabytes
      #   has_attachment :content_type => 'application/pdf'
      #   has_attachment :content_type => ['application/pdf', 'application/msword', 'text/plain']
      #   has_attachment :content_type => :image, :resize_to => [50,50]
      #   has_attachment :content_type => ['application/pdf', :image], :resize_to => 'x50'
      #   has_attachment :thumbs => { :thumbnail => [50, 50] }
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files'
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files', 
      #     :content_type => :image, :resize_to => [50,50]
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files',
      #     :thumbs => { :thumbnail => [50, 50], :geometry => 'x50' }
      #   has_attachment :storage => :s3
      def has_attachment(options = {})
        # this allows you to redefine the acts' options for each subclass, however
        options[:min_size]         ||= 1
        options[:max_size]         ||= 1.megabyte
        options[:size]             ||= (options[:min_size]..options[:max_size])
        options[:thumbs]           ||= {}
        options[:thumbnail_class]  ||= self
        options[:s3_access]        ||= :public_read
        options[:content_type] = [options[:content_type]].flatten.collect! { |t| t == :image ? Technoweenie::AttachmentFu.thumb_content_types : t }.flatten unless options[:content_type].nil?
        
        unless options[:thumbs].is_a?(Hash)
          raise ArgumentError, ":thumbs option should be a hash: e.g. :thumbs => { :foo => [150,150] }"
        end
        
        # doing these shenanigans so that #attachment_options is available to processors and backends
        class_inheritable_accessor :attachment_options
        self.attachment_options = options

        # only need to define these once on a class
        unless included_modules.include?(InstanceMethods)
          attr_accessor :thumbnail_resize_options
          attr_writer :thumbs

          attachment_options[:storage]     ||= (attachment_options[:file_system_path] || attachment_options[:path_prefix]) ? :file_system : :db_file
          attachment_options[:path_prefix] ||= attachment_options[:file_system_path]
          if attachment_options[:path_prefix].nil?
            attachment_options[:path_prefix] = attachment_options[:storage] == :s3 ? table_name : File.join("public", table_name)
          end
          attachment_options[:path_prefix]   = attachment_options[:path_prefix][1..-1] if options[:path_prefix].first == '/'

          with_options :foreign_key => 'parent_id' do |m|
            m.has_many   :thumbnails, :class_name => attachment_options[:thumbnail_class].to_s
            m.belongs_to :parent, :class_name => base_class.to_s
          end
          before_destroy :destroy_thumbnails

          before_validation :download
          after_save :after_process_attachment
          after_destroy :destroy_file
          extend  ClassMethods
          include InstanceMethods
          include Technoweenie::AttachmentFu::Backends.const_get("#{options[:storage].to_s.classify}Backend")
          case attachment_options[:processor]
            when :none
            when nil
              processors = Technoweenie::AttachmentFu.default_processors.dup
              begin
                include Technoweenie::AttachmentFu::Processors.const_get("#{processors.first}Processor") if processors.any?
              rescue LoadError, MissingSourceFile
                processors.shift
                retry
              end
            else
              begin
                include Technoweenie::AttachmentFu::Processors.const_get("#{options[:processor].to_s.classify}Processor")
              rescue LoadError, MissingSourceFile
                puts "Problems loading #{options[:processor]}Processor: #{$!}"
              end
          end
          before_save :process_attachment
          before_save :calculate_summary_metrics
          before_save :evaluate_custom_callbacks
        end
      end
    end

    module ClassMethods
      delegate :content_types, :to => Technoweenie::AttachmentFu
      delegate :thumb_content_types, :to => Technoweenie::AttachmentFu
      delegate :icon_content_types, :to => Technoweenie::AttachmentFu
      delegate :program_content_types, :to => Technoweenie::AttachmentFu

      # Performs common validations for attachment models.
      def validates_as_attachment
        validate                :valid_source?
        validates_presence_of   :content_type
        validate                :valid_content_type?
        validates_presence_of   :filename, :if => :local?
        validates_inclusion_of  :size, :in => attachment_options[:size], :if => Proc.new{|r| r.local? && r.thumbnail.nil?}
      end

      # Returns true or false if the given content type is recognized as an image.
      def image?(content_type)
        thumb_content_types.include?(content_type)
      end
      
      # Get the thumbnail class, which is the current attachment class by default.
      # Configure this with the :thumbnail_class option.
      def thumbnail_class
        attachment_options[:thumbnail_class] = attachment_options[:thumbnail_class].constantize unless attachment_options[:thumbnail_class].is_a?(Class)
        attachment_options[:thumbnail_class]
      end

      # Copies the given file path to a new tempfile, returning the closed tempfile.
      # NB: Under Win32 on Ruby 1.8.6, tempfiles are not usually deleted due to silent failures in the unlink method.
      def copy_to_temp_file(file, temp_base_name)
        returning Tempfile.new(temp_base_name, Technoweenie::AttachmentFu.tempfile_path) do |tmp|
          tmp.close
          FileUtils.cp file, tmp.path
        end
      end
      
      # Writes the given data to a new tempfile, returning the closed tempfile.
      # NB: Under Win32 on Ruby 1.8.6, tempfiles are not usually deleted due to silent failures in the unlink method.
      def write_to_temp_file(data, temp_base_name)
        returning Tempfile.new(temp_base_name, Technoweenie::AttachmentFu.tempfile_path) do |tmp|
          tmp.binmode
          tmp.write data
          tmp.close
        end
      end
    end

    module InstanceMethods
      def self.included( base )
        base.define_callbacks *[:after_resize, :after_attachment_saved, :before_save_attachment, :before_save_thumbnail, :before_thumbnail_saved]
      end  
  
      # Trigger appropriate custom callbacks.
      def evaluate_custom_callbacks
        if thumbnail?
          callback(:before_save_thumbnail)
        else
          callback(:before_save_attachment)
        end
      end
      
      # Checks whether the attachment's content type is an image content type
      def image?
        self.class.image?(content_type)
      end
      
      # Returns true/false if an attachment is thumbnailable.  A thumbnailable attachment has an 
      # image content type and a parent_id attribute, and uses local storage.
      def thumbnailable?
        image? && respond_to?(:parent_id) && parent_id.nil? && local?
      end
      
      # Returns predicate based on attachment being expected to be stored locally or already stored locally
      def local?
        new_record? ? save_attachment? : attachment_present?
      end
      
      def remote?
        !self[:url].nil?
      end

      # Returns the class used to create new thumbnails for this attachment.
      def thumbnail_class
        self.class.thumbnail_class
      end

      # Gets the thumbnail name for a filename.  'foo.jpg' becomes 'foo_thumbnail.jpg'
      def thumbnail_name_for(thumbnail = nil)
        return filename if thumbnail.blank?
        ext = nil
        basename = filename.gsub /\.\w+$/ do |s|
          ext = s; ''
        end
        "#{basename}_#{thumbnail}#{ext}"
      end

      # Creates or updates the thumbnail for the current attachment.
      def create_or_update_thumbnail(ttype, attrs)
        raise(ThumbnailError.new("Can't create a thumbnail of a thumbnail")) unless parent_id.nil?
        returning find_or_initialize_thumbnail(ttype) do |thumb|
          thumb.attributes = attrs.merge!({:thumbs => {}})
          callback :before_thumbnail_saved
          thumb.save!
        end
      end

      # Sets the content type.
      def content_type=(new_type)
        write_attribute :content_type, new_type.to_s.strip
      end
      
      # Sanitizes a filename.
      def filename=(new_name)
        write_attribute :filename, sanitize_filename(new_name)
      end

      # Returns the width/height in a suitable format for the image_tag helper: (100x100)
      def image_size
        [width.to_s, height.to_s] * 'x'
      end

      # Returns true if the attachment data will be written to the storage system on the next save
      def save_attachment?
        File.file?(temp_path.to_s)
      end

      # nil placeholder in case this field is used in a form.
      def file() nil; end

      # This method handles the uploaded file object.  If you set the field name to file, you don't need
      # any special code in your controller.
      #
      #   <% form_for :attachment, :html => { :multipart => true } do |f| -%>
      #     <p><%= f.file_field :file %></p>
      #     <p><%= submit_tag :Save %>
      #   <% end -%>
      #
      #   @attachment = Attachment.create! params[:attachment]
      #
      # TODO: Allow it to work with Merb tempfiles too.
      def file=(file_data)
        return nil if file_data.nil? || file_data.size == 0 
        self.content_type = file_data.content_type
        self.filename     = file_data.original_filename if respond_to?(:filename)
        self.size         = file_data.size
        if file_data.is_a?(StringIO)
          file_data.rewind
          self.temp_data = file_data.read
        else
          self.temp_path = file_data.path
        end
      end

      # Gets the latest temp path from the collection of temp paths.  While working with an attachment,
      # multiple Tempfile objects may be created for various processing purposes (resizing, for example).
      # An array of all the tempfile objects is stored so that the Tempfile instance is held on to until
      # it's not needed anymore.
      def temp_path
        p = temp_paths.first
        p.respond_to?(:path) ? p.path : p.to_s if p
      end
      
      # Gets an array of the currently used temp paths.  Upon initialization, a temp_file of the current data is created.
      def temp_paths
        @temp_paths ||= (new_record? ? [] : [create_temp_file])
      end
      
      # Adds a new temp_path to the array.  This should take a string or a Tempfile.  This class makes no 
      # attempt to remove the files, so Tempfiles should be used.  Tempfiles remove themselves when they go out of scope.
      # You can also use string paths for temporary files, such as those used for uploaded files in a web server.
      def temp_path=(value)
        temp_paths.unshift value
        temp_path
      end

      # Gets the data from the latest temp file.  This will read the file into memory.
      def temp_data
        save_attachment? ? File.open(temp_path, "rb").read : nil
      end
      
      # Writes the given data to a Tempfile and adds it to the collection of temp files.
      def temp_data=(data)
        self.temp_path = write_to_temp_file data unless data.nil?
      end
      
      # Copies the given file to a randomly named Tempfile.
      def copy_to_temp_file(file)
        self.class.copy_to_temp_file file, random_tempfile_filename
      end
      
      # Writes the given file to a randomly named Tempfile.
      def write_to_temp_file(data)
        self.class.write_to_temp_file data, random_tempfile_filename
      end
      
      # Stub for creating a temp file from the attachment data.  This should be defined in the backend module.
      def create_temp_file() end

      # Allows you to work with a processed representation (RMagick, ImageScience, etc) of the attachment in a block.
      #
      #   @attachment.with_image do |img|
      #     self.data = img.thumbnail(100, 100).to_blob
      #   end
      #
      def with_image(&block)
        raise "Local processing not currently supported with with remote images." unless local?
        self.class.with_image(temp_path, &block)
      end

      # Evaluate if a download is required and select the right HTTP method.  Don't bother downloading 
      # if we've been given the metadata directly.  And don't download if there is no URL, of course.
      def download
        begin
          download!(self[:url], http_method_required, 5) if self[:url] and not (self.size and self.content_type)
        rescue => e
          errors.add(:url, e.message)
          false
        end
      end
      
      # Download from URL.  Attachment metadata is loaded from the header only if method is :head.  If the method
      # is :get, the body is returned and used to calculate the metadata.
      def download!(url = self.url, method = :head, count = 5)
        uri = URI.parse(url)
        Net::HTTP.start(uri.host) do |http|
          response = http.send(method, uri.path)
          case response
            when Net::HTTPSuccess
              self.content_type = response.content_type
              if response.body.nil? or response.body.size.zero? or self.class.program_content_types.include?(content_type)
                self.size = response.content_length
                self.digest = ActiveSupport::Base64.decode64(response['Content-MD5']) unless response['Content-MD5'].nil? 
              else
                self.size = response.body.size
                self.temp_data = response.body
                self.filename = uri.path.split('/')[-1]
              end
            when Net::HTTPRedirection
              raise ArgumentError, "URL results in too many redirections." if count.zero?
              return download!(response['location'], method, count-1)
            else
              raise ArgumentError, "Couldn't open URL"
            end
        end
      end
  
      # Returns the HTTP method required (GET or HEAD) based on the thumbnail options.
      def http_method_required
        thumbs.each do |ttype, toption|
          return :get if [Array, Geometry].include?(toption.class)
        end
        :head
      end
      
      # Returns a hash of rules for how to build various thumbnails.  Defaults from the has_attachment method
      # can be overridden in the constructor options with the :thumbs psuedo-attribute.
      def thumbs
        @thumbs ||= (attachment_options[:thumbs] || {})
      end
      
      def mime_type
        @mime_type ||= Mime::Type.lookup(self.attributes['content_type'])
      end
      
      def mime_type=(mt)
        @mime_type = mt.kind_of?(Mime::Type) ? mt : Mime::Type.lookup(mt)
        write_attribute(:content_type, @mime_type.to_s)
        @mime_type
      end
    
      # Validate that one or the other of the attachment sources is present.
      def valid_source?
        returning (self.local? || self[:url]) do |present|
          self.errors.add_to_base('Attachment must have exactly one source.') unless present
        end
      end
  
      protected
        # Generates a unique filename for a Tempfile. 
        def random_tempfile_filename
          "#{rand Time.now.to_i}#{filename || 'attachment'}"
        end

        def sanitize_filename(filename)
          returning filename.strip do |name|
            # NOTE: File.basename doesn't work right with Windows paths on Unix
            # get only the filename, not the whole path
            name.gsub! /^.*(\\|\/)/, ''
            
            # Finally, replace all non alphanumeric, underscore or periods with underscore
            name.gsub! /[^\w\.\-]/, '_'
          end
        end

        # validates the content_type attribute according to the current model's options
        def valid_content_type?
          whitelist = attachment_options[:content_type]
          errors.add :content_type, ActiveRecord::Errors.default_error_messages[:inclusion] unless whitelist.nil? || whitelist.include?(self.content_type)
        end

        # Initializes a new thumbnail with the given suffix.
        def find_or_initialize_thumbnail(file_name_suffix)
          respond_to?(:parent_id) ?
            thumbnails.find_or_initialize_by_thumbnail(file_name_suffix.to_s) :
            thumbnail_class.find_or_initialize_by_thumbnail(file_name_suffix.to_s)
        end

        # Stub for a #process_attachment method in a processor
        def process_attachment
          @saved_attachment = save_attachment?
        end

        def calculate_summary_metrics
          if save_attachment?
            self.size   = File.size(temp_path)
            self.digest = Digest::MD5.digest(temp_data)
          end
        end
        
        # Cleans up after processing.  Thumbnails are created, the attachment is stored to the backend, and the temp_paths are cleared.
        def after_process_attachment
          thumbs.each do |ttype, tsource|
            unless tsource.nil?
              case tsource
                when Array, Geometry
                  # Don't bother trying to create a thumbnail if no data was saved (particularly when a URL cannot be retrieved)
                  if @saved_attachment && respond_to?(:process_attachment_with_processing)
                    toptions = {
                        :content_type             => content_type, 
                        :filename                 => thumbnail_name_for(ttype), 
                        :temp_path                => temp_path || create_temp_file,
                        :thumbnail_resize_options => tsource
                    }
                  end
                when String
                  toptions = {:url => tsource}
                when Hash
                  toptions = tsource
                else
                  if tsource.respond_to?(:original_filename)
                    toptions = {:file => tsource}
                  else
                    raise RuntimeError, "Don't know how to make this #{ttype}: #{tsource}."
                  end
              end # case
              # Create a thumbnail based on the processing rules -if any (reference-only URLs 
              # won't even get default thumbnail processing)
              create_or_update_thumbnail(ttype, toptions) if toptions
            end # unless
          end # each
          if @saved_attachment
            save_to_storage
            @saved_attachment = nil
            callback :after_attachment_saved
          end
        end

        # Resizes the given processed img object with either the attachment resize options or the thumbnail resize options.
        def resize_image_or_thumbnail!(img)
          if (!respond_to?(:parent_id) || parent_id.nil?) && attachment_options[:resize_to] # parent image
            resize_image(img, attachment_options[:resize_to])
          elsif thumbnail_resize_options # thumbnail
            resize_image(img, thumbnail_resize_options) 
          end
        end

        # Removes the thumbnails for the attachment, if it has any
        def destroy_thumbnails
          self.thumbnails.each { |thumbnail| thumbnail.destroy } if thumbnailable?
        end
    end
  end
end
