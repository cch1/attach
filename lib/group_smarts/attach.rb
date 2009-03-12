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
    class MissingSource < StandardError; end

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
          attr_accessor :resize, :iconify
          attr_accessor :store  # indicates whether or not to store attachment data.  Set to false to not store data and instead use a remote reference
          attr_writer :_aspects # Array or Hash of aspects to create.  Set to an empty array to not create any aspects.

          attachment_options[:store] ||= Proc.new {|id, aspect, extension| "db://localhost/attachment_blobs/#{id}"}

          with_options :foreign_key => 'parent_id' do |m|
            m.has_many   :aspects, :class_name => base_class.to_s, :dependent => :destroy
            m.belongs_to :parent, :class_name => base_class.to_s
          end
          
          has_one :attachment_blob, :class_name => 'GroupSmarts::Attach::AttachmentBlob', :dependent => :destroy if GroupSmarts::Attach::AttachmentBlob.table_exists?
          delegate :blob, :to => :source


          before_validation :process!
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
        validates_presence_of   :filename, :if => :local?
        validates_presence_of   :content_type
        validate                :valid_content_type?
        validates_presence_of   :uri
        validate                :valid_uri?
        validate                :valid_source?
        validates_inclusion_of  :size, :in => attachment_options[:size], :if => :local?
      end

      # Returns true or false if the given content type is recognized as an image.
      def image?(content_type)
        image_content_types.include?(content_type)
      end
      
      # Builds a URI where the attachment should be stored 
      def storage_uri(id, aspect, extension)
        ::URI.parse(attachment_options[:store].call(id, aspect, extension))
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
        uri && %w(file db s3).include?(uri.scheme)
      end
      
      # Returns the width/height in a suitable format for the image_tag helper: (100x100)
      def image_size
        [metadata[:width].to_s, metadata[:height].to_s] * 'x' if metadata && metadata[:width] && metadata[:height]
      end

      # Getter for file virtual attribute for consistency with setter.  Useful in case this field is used in a form.
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
      def file=(upload)
        return unless upload
        self.store = true if store.nil?
        self.source = Sources::Base.load(upload, cgi_metadata(upload))
      end
      
      # Getter for url virtual attribute for consistency with setter.  Useful in case this field is used in a form.
      def url
        local? ? nil : uri.to_s
      end

      # Setter for virtual url attribute used to reference external data sources.
      def url=(u)
        return unless u
        self.store = false if store.nil?
        self.source = Sources::Base.load(::URI.parse(u))
      end
      
      # Get the source.
      def source
        @source ||= uri && Sources::Base.reload(uri)
      end
      
      # Set the source.
      def source=(src)
        raise "Source should be an instance of Attach::Sources::Base or its subclasses." unless src.kind_of?(Sources::Base)
        raise "Source is not valid." unless src.valid?
        a = {}
        self.metadata = src.metadata.reject{|k,v| a[k] = v if respond_to?(k)}
        self.attributes = a
        @source = src
        @source_updated = true
        @_aspects ||= attachment_options[:_aspects].dup || [] # Unless overridden, we need to update the aspects now that the source has changed.
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

      # Returns the array of aspects to be built for this attachment.
      def _aspects
        return [] if parent
        @_aspects ||= []
      end
      
      # Return an instance of ::URI that points to the attachment's data source.
      def uri
        @uri ||= URI.parse(read_attribute(:uri)) if read_attribute(:uri)
      end
      
      # Setter for URI.  Accepts a string representation of a URI, or a ::URI instance.
      def uri=(u)
        @uri = u && (u.kind_of?(::URI) ? u : ::URI.parse(u).normalize)
        @uri && write_attribute(:uri, @uri.to_s)
      end
      
      # Getter for MIME type.  Returns an instance of Mime::Type
      def mime_type
        @mime_type ||= Mime::Type.lookup(read_attribute(:content_type))
      end
      
      # Setter for Mime type.  Accepts a string representation of a Mime type, or a ::Mime::Type instance.
      def mime_type=(mt)
        # TODO: Scrap the ability to read a string -that's what the built-in setter on content_type is for.
        # TODO: Convert this to a composed_of macro? 
        @mime_type = mt && (mt.kind_of?(Mime::Type) ? mt : Mime::Type.lookup(mt))
        @mime_type && write_attribute(:content_type, @mime_type.to_s)
      end
      
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
        
        # Ensure source is valid, and if not, update the ActiveRecord errors object with the source error.
        def valid_source?
          source && returning(source.valid?) do |valid|
            errors.add_to_base(source.error) unless valid
          end          
        end

        # Process the source and load the resulting metadata.  No processing of the primary attachment should impede the creation of aspects.
        def process!
          if source && source.valid? && required_processing
            logger.debug "Attach: PROCESSING     #{self} (#{source} @ #{source.uri}) with #{required_processing}\n"
            self.source = Sources::Base.process(source, required_processing)
          end
          true
        end
        
        # Returns true if the original attachment or any of its aspects require data for processing (best guess) or storing.
        # Manually defined _aspects (via attribute) are assumed to not require data for processing unless the store attribute is also set.
        def data_required?
          store || image? && _aspects.any? do |a|
            name, attributes = *a
            attributes.nil? ? Sources::Base::AvailableImageProcessing.include?(name) : attributes[:store]
          end
        end

        # Returns the processing required for the attachment.
        def required_processing
          @source_updated && case
            when store && image? && resize
              resize
            when aspect && image? && Sources::Base::AvailableImageProcessing.include?(aspect.to_sym)
              aspect
            when aspect && iconify
              :iconify
            when !aspect && data_required?  # Opportunistically extract bonus metadata for original attachment if the source data is/will be required.
              :info
          end
        end
      
        # Choose the storage URI.  Done early so that it may be validated and allow attachment data blobs to be stored before or after main attachment record.
        def choose_storage
          return unless source
          self.uri = source.uri unless store
          self.uri ||= self.class.storage_uri(uuid!, aspect, mime_type.to_sym)
        end
        
        # Create additional child attachments for each requested aspect.
        def create_aspects
          _aspects.each do |a|
            raise(AspectError.new("Can't create an aspect of an aspect")) unless parent_id.nil?
            name, attributes = *a
            attributes ||= {:source => source}
            logger.debug "Attach: CREATE ASPECT  #{self} (#{source} @ #{source.uri}) as #{name}\n"
            returning aspects.find_or_initialize_by_aspect(name.to_s) do |_aspect|
              _aspect.attributes = attributes.merge!({:attachee => attachee, :_aspects => {}})
              _aspect.save!
            end
          end
          _aspects.clear
          true
        end

        # Store the attachment to the backend, if required, and trigger associated callbacks.
        # Sources are saved to the location identified by the uri attribute if the store attribute is set.
        def save_source
          if @source_updated && uri.host == 'localhost'
            @source_updated = nil # Indicate that no further storage is necessary.
            logger.debug "Attach: SAVE SOURCE    #{self} (#{source} @ #{source.uri}) to #{uri}\n"
            self.source = Sources::Base.store(source, uri)
          end
        end

        def destroy_source
          source.destroy 
        rescue MissingSource
          true # If the source is missing, carry on.
        end
        
        # Removes the aspects for the attachment, if it has any
        def destroy_aspects
          self.aspects(true).each { |a| a.destroy }
        end
        
        private
        def cgi_metadata(data)
          returning(Hash.new) do |md|
            md[:filename] = data.original_filename if data.respond_to?(:original_filename) 
            md[:content_type] = ::Mime::Type.lookup(data.content_type) if data.respond_to?(:content_type) 
          end
        end
    end
  end
end