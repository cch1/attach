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
      # *  <tt>:resize</tt> - Used by RMagick to resize images.  Pass either an array of width/height, or a geometry string.
      # *  <tt>:thumbnails</tt> - Specifies a set of thumbnails to generate.  This accepts a hash of thumb types (key) and resizing options or sources.
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
          attr_accessor :resize
          attr_accessor :store  # indicates whether remote attachments should be downloaded and stored locally
          attr_reader :source # holds data source for new instances
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

          before_validation :process_attachment
          before_save :evaluate_custom_callbacks
          after_save :process_thumbnails
          after_save :save_attachment
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
        end
      end
    end

    module ClassMethods
      def self.extended(base)
        unless defined?(::ActiveSupport::Callbacks)
          def before_save_thumbnail(&block)
            write_inheritable_array(:before_save_thumbnail, [block])
          end
          def before_save_attachment(&block)
            write_inheritable_array(:before_save_attachment, [block])
          end
        end
      end
      
      delegate :content_types, :to => Technoweenie::AttachmentFu
      delegate :thumb_content_types, :to => Technoweenie::AttachmentFu
      delegate :icon_content_types, :to => Technoweenie::AttachmentFu
      delegate :program_content_types, :to => Technoweenie::AttachmentFu

      # Performs common validations for attachment models.
      def validates_as_attachment
        validates_presence_of   :content_type
        validate                :valid_content_type?
        validates_presence_of   :filename
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
      # NB: This method looks bogus.  The Tempfile.new method returns a file with the necessary properties.  Copying an existing file onto the name
      #     previously held by a tempfile does not make the copy a Tempfile. 
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
        base.define_callbacks *[:after_resize, :after_attachment_saved, :before_save_attachment, :before_save_thumbnail, :before_thumbnail_saved] if base.respond_to?(:define_callbacks)
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
      
      # Returns predicate based on attachment being expected to be stored locally or already stored locally
      def local?
        new_record? ? store : attachment_present?
      end
      
      # Returns the class used to create new thumbnails for this attachment.
      def thumbnail_class
        self.class.thumbnail_class
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
        write_attribute :filename, new_name && sanitize_filename(new_name)
      end

      # Returns the width/height in a suitable format for the image_tag helper: (100x100)
      def image_size
        [width.to_s, height.to_s] * 'x'
      end

      # Returns true if there is unstored attachment data that should be written to the storage system on the next save
      def save_attachment?
        source && store
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
        self.store = true
        self.source = Technoweenie::AttachmentFu::Sources::CGIUpload.new(file_data)
      end
      
      def url=(u)
        self.source = Technoweenie::AttachmentFu::Sources::URI.new(u, store || process_attachment?)
        self[:url] = u
      end
      
      # Returns true if the source must be processed (either as an attachment or in the process of creating a thumbnail).
      def process_attachment?
        c1 = resize && store # This attachment is to be stored locally and it should be resized
        c2 = thumbs.each do |ttype, toption|
          return true if [Array, Geometry].include?(toption.class)
        end
        c1 || c2
      end
      
      # Update the source and check for source collisions.
      def source=(s)
        raise "Attachment source collision." unless @source.nil?
        update_source(s)
      end
      
      # Store the source and flag the update.
      def update_source(new_source)
        @source_udpated = true
        load_metadata(new_source)
        self.temp_path = new_source.tempfile
        @source = new_source
      end
      
      # Gets the latest temp path from the collection of temp paths.  While working with an attachment,
      # multiple Tempfile objects may be created for various processing purposes (resizing, for example).
      # An array of all the tempfile objects is stored so that the Tempfile instance is held on to until
      # it's not needed anymore.
      def temp_path
        temp_paths.first
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
        self.class.with_image(temp_path, &block)
      end

      # Load metadata, where missing, from the (external) source.
      def load_metadata(s)
        begin
          self.filename = s.filename
          self.size = s.size
          self.digest = s.digest
          self.content_type = s.content_type
          true
        rescue => e
          errors.add(:base, e.message)
          false
        end
      end
      
      # Returns a hash of rules for how to build various thumbnails.  Defaults from the has_attachment method
      # can be overridden in the constructor options with the :thumbs psuedo-attribute.
      def thumbs
        @thumbs ||= attachment_options[:thumbs] || {}
      end
      
      def mime_type
        @mime_type ||= Mime::Type.lookup(self.attributes['content_type'])
      end
      
      def mime_type=(mt)
        @mime_type = mt.kind_of?(Mime::Type) ? mt : Mime::Type.lookup(mt)
        write_attribute(:content_type, @mime_type.to_s)
        @mime_type
      end
    
      protected
        # Generates a unique filename for a Tempfile. 
        def random_tempfile_filename
          "#{rand Time.now.to_i}#{filename || 'attachment'}"
        end

        def sanitize_filename(filename)
          returning filename && filename.strip do |name|
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

        # Stub for a #process_attachment method in a processor.  Return true if the image should be processed.
        def process_attachment
          process_attachment?
        end

        # Store the attachment to the backend, if required, and trigger associated callbacks.
        def save_attachment
          if save_attachment?
            save_to_storage
            callback :after_attachment_saved
          end
        end
      
        # Create additional child attachments for each requested thumbnail.  Thumbnails can be specificed in various ways...
        def process_thumbnails
          thumbs.each do |ttype, tsource|
            unless tsource.nil?
              case tsource
                when Array, Geometry  # ex. :thumbnail => [100, 100]
                  # Don't bother trying to create a thumbnail if no data was saved (particularly when a URL cannot be retrieved)
                  if image? && self.source && respond_to?(:process_attachment_with_processing)
                    toptions = {:source => source, :resize => tsource, :store => true}
                  end
                when String  # example: :thumbnail => 'http://flickr.com/c47xx35' <- This should be replaced with hash!
                  toptions = {:url => tsource}
                when Hash  # example: :thumbnail => {:url => 'http://flickr.com/9876vch33'}
                  toptions = tsource
                else  # example: thumbnail => {<CGI File object>}  <- This should be replaced with hash!
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
        end

        # Removes the thumbnails for the attachment, if it has any
        def destroy_thumbnails
          self.thumbnails.each { |thumbnail| thumbnail.destroy }
        end
    end
  end
end
