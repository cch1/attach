module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    @@default_processors = %w(ImageScience Rmagick MiniMagick)
    @@tempfile_path      = File.join(RAILS_ROOT, 'tmp', 'attach')
    @@image_content_types = ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg', 'image/bmp']
    @@program_content_types = ['text/html']
    @@icon_content_types = @@program_content_types + ['application/xls']
    @@content_types = @@image_content_types + @@icon_content_types
    mattr_reader :content_types, :image_content_types, :icon_content_types, :program_content_types
    mattr_reader :tempfile_path, :default_processors
    mattr_writer :tempfile_path

    class AspectError < StandardError;  end
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
      #   has_attachment :_aspects => { :thumbnail => [50, 50] }
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files'
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files', 
      #     :content_type => :image, :resize_to => [50,50]
      #   has_attachment :storage => :file_system, :path_prefix => 'public/files',
      #     :_aspects => { :thumbnail => [50, 50], :geometry => 'x50' }
      #   has_attachment :storage => :s3
      def has_attachment(options = {})
        # this allows you to redefine the acts' options for each subclass, however
        options[:min_size]         ||= 1
        options[:max_size]         ||= 1.megabyte
        options[:size]             ||= (options[:min_size]..options[:max_size])
        options[:_aspects]         ||= []
        options[:s3_access]        ||= :public_read
        options[:content_type] = [options[:content_type]].flatten.collect! { |t| t == :image ? GroupSmarts::Attach.image_content_types : t }.flatten unless options[:content_type].nil?
        
        unless options[:_aspects].is_a?(Array)
          raise ArgumentError, ":The aspects option should be an array: e.g. :aspects => [:thumbnail, :proof]"
        end
        
        # doing these shenanigans so that #attachment_options is available to processors and backends
        class_inheritable_accessor :attachment_options
        self.attachment_options = options

        # only need to define these once on a class
        unless included_modules.include?(InstanceMethods)
          attr_accessor :resize
          attr_accessor :store  # indicates where to store attachment data.  Set to false to not store data and instead use a remote reference
          attr_writer :_aspects # Array of aspects to create.

          attachment_options[:store] ||= 'db://localhost/db_file/%s'
          attachment_options[:path_prefix] ||= attachment_options[:file_system_path]
          if attachment_options[:path_prefix].nil?
            attachment_options[:path_prefix] = attachment_options[:store] == :s3 ? table_name : File.join("public", table_name)
          end
          attachment_options[:path_prefix]   = attachment_options[:path_prefix][1..-1] if options[:path_prefix].first == '/'

          with_options :foreign_key => 'parent_id' do |m|
            m.has_many   :aspects, :class_name => base_class.to_s, :dependent => :destroy
            m.belongs_to :parent, :class_name => base_class.to_s
          end
          
          has_one :attachment_blob, :dependent => :destroy if ::AttachmentBlob

          before_validation :process_source
          before_validation :choose_storage
          before_save :save_source
          before_save :evaluate_custom_callbacks
          after_save :create_aspects
          after_destroy :destroy_aspects
          after_destroy :destroy_source
          extend  ClassMethods
          include InstanceMethods
        end
      end
    end

    module ClassMethods
      def self.extended(base)
        unless defined?(::ActiveSupport::Callbacks)
          def before_save_aspect(&block)
            write_inheritable_array(:before_save_aspect, [block])
          end
          def before_save_attachment(&block)
            write_inheritable_array(:before_save_attachment, [block])
          end
        end
      end
      
      delegate :content_types, :to => GroupSmarts::Attach
      delegate :image_content_types, :to => GroupSmarts::Attach
      delegate :icon_content_types, :to => GroupSmarts::Attach
      delegate :program_content_types, :to => GroupSmarts::Attach

      # Performs common validations for attachment models.
      def validates_as_attachment
        validates_presence_of   :content_type
        validate                :valid_content_type?
        validates_presence_of   :uri
        validate                :valid_uri?
#        validates_inclusion_of  :size, :in => attachment_options[:size], :if => Proc.new{|r| r.local?}
      end

      # Returns true or false if the given content type is recognized as an image.
      def image?(content_type)
        image_content_types.include?(content_type)
      end
    end

    module InstanceMethods
      def self.included( base )
        base.define_callbacks *[:before_save_attachment, :before_save_aspect] if base.respond_to?(:define_callbacks)
      end  

      # Trigger appropriate custom callbacks.
      def evaluate_custom_callbacks
        if aspect?
          callback(:before_save_aspect)
        else
          callback(:before_save_attachment)
        end
      end
      
      # Checks whether the attachment's content type is an image content type
      def image?
        self.class.image?(content_type)
      end
      
      # Returns predicate based on attachment being hosted locally (will be stored locally or already stored locally)
      # OPTIMIZE: Consider having this be a method on source for encapsulation.
      def local?
        %w(file db s3).include?(uri && uri.scheme)
      end
      
      # Return a filename for the attachment
      def filename
        #uri.path.split('/')[-1] || 'attachment'
        self[:filename] || [id, aspect, mime_type.to_sym].compact.join('_')
      end

      # Returns the width/height in a suitable format for the image_tag helper: (100x100)
      def image_size
        [metadata[:width].to_s, metadata[:height].to_s] * 'x' if metadata && metadata[:width] && metadata[:height]
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
        self.store = true if store.nil?
        self.source = Sources::Base.load(file_data)
      end
      
      def url=(u)
        self.store = false if store.nil?
        self.source = Sources::Base.load(::URI.parse(u))
      end
      
      # Get the source.
      def source
        @source ||= Sources::Base.load(uri)
      end
      
      # Set the source.
      def source=(src)
        raise "Source should be an instance of Attach::Sources::Base or its subclasses." unless src.kind_of?(Sources::Base)
        raise "Source is not valid." unless src.valid?
        a = {}
        self.metadata = src.metadata.reject{|k,v| a[k] = v if respond_to?(k)}
        self.attributes = a
        @source = src
        @_aspects ||= attachment_options[:_aspects].dup || []
      end
      
      # Allows you to work with a processed representation (RMagick, ImageScience, etc) of the attachment in a block.
      #
      #   @attachment.with_image do |img|
      #     self.data = img.thumbnail(100, 100).to_blob
      #   end
      #
      def with_image(&block)
        self.source = source.process(:identity)
        yield source.image
      end

      # Returns an array of aspects to be built for this attachment.
      def _aspects
        @_aspects ||= []
      end
      
      # Return an instance of ::URI that points to the attachment's data source.
      def uri
        @uri ||= URI.parse(read_attribute(:uri)) if read_attribute(:uri)
      end
      
      # Setter for URI.  Accepts a string representation of a URI, or a ::URI instance.
      def uri=(u)
        @uri = u.kind_of?(::URI) ? u : ::URI.parse(u).normalize
        write_attribute(:uri, @uri.to_s)
        @uri
      end
      
      # Getter for MIME type.  Returns an instance of Mime::Type
      def mime_type
        @mime_type ||= Mime::Type.lookup(read_attribute(:content_type))
      end
      
      # Setter for Mime type.  Accepts a string representation of a Mime type, or a ::Mime::Type instance.
      def mime_type=(mt)
        # TODO: Scrap the ability to read a string -that's what the built-in setter on content_type is for.
        # TODO: Convert this to a composed_of macro? 
        @mime_type = mt.kind_of?(Mime::Type) ? mt : Mime::Type.lookup(mt)
        write_attribute(:content_type, @mime_type.to_s)
        @mime_type
      end
      
      # Return the raw data (blob) of this attachment
      def blob
        source.blob
      end
      alias current_data blob # For backwards compatibility with AttachmentFu
    
      protected
        # validates the content_type attribute according to the current model's options
        def valid_content_type?
          whitelist = attachment_options[:content_type]
          errors.add :content_type, ActiveRecord::Errors.default_error_messages[:inclusion] unless whitelist.nil? || whitelist.include?(self.content_type)
        end
        
        def valid_uri?
          begin
            errors.add(:uri, "URI must be absolute.") unless uri
          rescue
            errors.add(:uri, "Can't be parsed") # Require that the string representation be parseable.
          end
        end

        # Process the source and load the resulting metadata.  If it's invalid, stop the validation chain.
        def process_source
          self.source = Sources::Base.process(source, required_processing) if source.valid? && required_processing
          returning source.valid? do |valid|
            errors.add_to_base(source.error) unless valid
          end
        end
        
        # Returns true if the original attachment or any of its aspects require data for processing (best guess) or storing.
        def data_required?
          store || _aspects.any? do |a|
            [:thumbnail, :icon, :proof].include?(a)
          end && image?
        end
      
        # Returns the processing required for the attachment.
        def required_processing
          p ||= resize if store && image?
          p ||= (image? ? aspect : :iconify) if aspect && store
          p ||= :info if !aspect && data_required?     # Opportunistically extract bonus metadata from "primary" attachments if the source's data is/will be required.
          @processing || p
        end
      
        # Choose the storage URI.  Done early so that it may be validated and allow attachment data blobs to store before or after main attachment record.
        def choose_storage
          self.uri = store ? ::URI.parse(attachment_options[:store] % uuid!) : source.uri
        end
        
        # Create additional child attachments for each requested aspect.
        def create_aspects
          _aspects.each do |a|
            name, attributes = *a
            attributes ||= {:source => Sources::Base.load(source.blob.dup, source.metadata.dup), :store => true}
            raise(AspectError.new("Can't create an aspect of an aspect")) unless parent_id.nil?
            returning aspects.find_or_initialize_by_aspect(name.to_s) do |_aspect|
              _aspect.attributes = attributes.merge!({:attachee => attachee, :_aspects => {}})
              _aspect.save!
            end
          end
          @_aspects.clear
          true
        end

        # Store the attachment to the backend, if required, and trigger associated callbacks.
        # Sources are saved to the location identified by the store variable
        def save_source
          if store && uri.host == 'localhost'
             @store = nil # Indicate that no further storage is necessary.
            self.source = Sources::Base.store(source, uri)
          end
        end

        def destroy_source
          source.destroy
        end
        
        # Removes the aspects for the attachment, if it has any
        def destroy_aspects
          self.aspects(true).each { |a| a.destroy }
        end
    end
  end
end
