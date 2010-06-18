module Hapgood # :nodoc:
  module Attach # :nodoc:
    @@default_processors = %w(ImageScience Rmagick MiniMagick)
    @@image_content_types = ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg', 'image/bmp']
    @@program_content_types = ['text/html']
    @@icon_content_types = @@program_content_types + ['application/xls']
    @@content_types = @@image_content_types + @@icon_content_types
    mattr_reader :content_types, :image_content_types, :icon_content_types, :program_content_types
    mattr_reader :default_processors

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
      # *  <tt>:store</tt> - A proc that takes three arguments (id, aspect and extension) and returns a storage URI.
      #
      # Examples:
      #   has_attachment :max_size => 1.kilobyte
      #   has_attachment :size => 1.megabyte..2.megabytes
      #   has_attachment :content_type => 'application/pdf'
      #   has_attachment :content_type => ['application/pdf', 'application/msword', 'text/plain']
      #   has_attachment :content_type => :image, :resize_to => [50,50]
      #   has_attachment :content_type => ['application/pdf', :image], :resize_to => 'x50'
      #   has_attachment :_aspects => { :thumbnail => [50, 50] }
      def has_attachment(options = {})
        # this allows you to redefine the acts' options for each subclass, however
        options[:min_size]         ||= 1
        options[:max_size]         ||= 1.megabyte
        options[:size]             ||= (options[:min_size]..options[:max_size])
        options[:_aspects]         ||= []
        options[:s3_access]        ||= :public_read
        options[:content_type] = [options[:content_type]].flatten.collect! { |t| t == :image ? Hapgood::Attach.image_content_types : t }.flatten unless options[:content_type].nil?
        options[:store]            ||= Proc.new {|i, a, e| "file://localhost#{::File.join(RAILS_ROOT, 'public', 'attachments', [[i,a].compact.join('_'), e].join('.'))}"}

        raise ArgumentError, ":The aspects option should be an array: e.g. :aspects => [:thumbnail, :proof]" unless options[:_aspects].is_a?(Array)

        # doing these shenanigans so that #attachment_options is available to processors and backends
        class_inheritable_accessor :attachment_options
        self.attachment_options = options

        # only need to define these once on a class
        unless included_modules.include?(InstanceMethods)
          attr_accessor :resize, :iconify
          attr_accessor :store  # indicates whether or not to store attachment data.  Set to false to not store data and instead use a remote reference
          attr_writer :processing # Queue of transformations to apply to the attachment.

          with_options :foreign_key => 'parent_id' do |m|
            m.has_many   :aspects, :class_name => base_class.to_s, :dependent => :destroy, :extend => AspectsAssociation
            m.belongs_to :parent, :class_name => base_class.to_s
          end

          delegate :blob, :public_uri, :to => :source

          before_validation :process!
          before_validation :schedule_default_aspects, :unless => :aspect
          before_save :save_source
          before_save :evaluate_custom_callbacks
          after_save :create_aspects
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

      delegate :content_types, :to => Hapgood::Attach
      delegate :image_content_types, :to => Hapgood::Attach
      delegate :icon_content_types, :to => Hapgood::Attach
      delegate :program_content_types, :to => Hapgood::Attach

      # Performs common validations for attachment models.
      def validates_as_attachment
        validates_presence_of   :filename, :if => :local?
        validates_presence_of   :content_type
        validate                :valid_content_type?
        validate                :valid_source?
        validates_inclusion_of  :size, :in => attachment_options[:size], :if => :local?
      end

      # Returns true or false if the given content type is recognized as an image.
      def image?(content_type)
        image_content_types.include?(content_type)
      end

      # Builds a URI where the attachment should be stored
      def storage_uri(id, aspect, mt)
        extension = mt.to_sym.to_s.gsub('/', '_') rescue nil
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

      # Setter for the (uploaded) file.
      def file=(upload)
        return unless upload
        destroy_source  # Discard any existing source
        aspects.clear
        begin
          self.source = Sources::Base.load(upload, cgi_metadata(upload))
        rescue  # Can't do much here -we have to wait until the validation phase to resurrect/reconstitute errors
        end
      end

      # Getter for url virtual attribute for consistency with setter.  Useful in case this field is used in a form.
      def url
        @url ||= local? ? nil : uri.to_s
      end

      # Setter for virtual url attribute used to reference external data sources.
      def url=(u)
        @url = u
        return unless u
        destroy_source  # Discard any existing source
        aspects.clear
        begin
          self.source = Sources::Base.load(::URI.parse(u))
        rescue  # Can't do much here -we have to wait until the validation phase to resurrect/reconstitute errors
        end
      end

      # Get the source.  Rescue exceptions and make them errors on the source virtual attribute.
      def source
        begin
          @source ||= uri && Sources::Base.reload(uri, stored_metadata)
        rescue => e
          self.errors.add(:source, e.to_s)
          return nil
        end
      end

      # Set the source.
      def source=(src)
        raise "Source should be an instance of Attach::Sources::Base or its subclasses." unless src.kind_of?(Sources::Base)
        raise "Source is not valid." unless src.valid?
        raise "Previous source should have been destroyed" if @source && (@source.persistent? && !@source.readonly? && (aspect.nil? || @source == parent.source))
        a = {}
        self.metadata = src.metadata.reject{|k,v| a[k] = v if respond_to?(k)}
        self.attributes = a
        @source = src
        @source_updated = true
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

      # Define the set of aspects to be created for this attachment.  Aspects can be defined in several ways:
      #   * a hash, with the aspect name as the key and a hash of attributes as the value
      #   * an array of symbols, each of which represents a standard transformation process
      # Note that an empty array will ensure no aspects are created.
      def _aspects=(instructions)
        raise "Can't make aspects of aspects" if parent
        @_aspects = instructions
      end

      # Returns the hash of aspects to be built for this attachment.
      def _aspects
        @_aspects ||= {}
      end

      # Schedule the creation of the default aspects
      def schedule_default_aspects
        @_aspects ||= attachment_options[:_aspects] if @source_updated
      end

      # Return an instance of ::URI that points to the attachment's data source.
      def uri
        @uri ||= URI.parse(read_attribute(:uri)) if read_attribute(:uri)
      end

      # Setter for URI.  Accepts a string representation of a URI, or a ::URI instance.
      def uri=(u)
        @uri = u && (u.kind_of?(::URI) ? u : ::URI.parse(u).normalize)
        write_attribute(:uri, @uri && @uri.to_s)
      end

      # Getter for MIME type.  Returns an instance of Mime::Type
      def mime_type
        @mime_type ||= Mime::Type.lookup(read_attribute(:content_type))
      end

      # Setter for MIME type.  Accepts a ::Mime::Type instance (for a string, use the content_type= setter and reset @mime_type)
      def mime_type=(mt)
        # TODO: Convert this to a composed_of macro, but only when :constructor is available in all supported Rails versions.
        @mime_type = mt
        write_attribute(:content_type, @mime_type && @mime_type.to_s)
      end

      protected
      # validates the content_type attribute according to the current model's options
      def valid_content_type?
        whitelist = attachment_options[:content_type]
        errors.add :content_type, ActiveRecord::Errors.default_error_messages[:inclusion] unless whitelist.nil? || whitelist.include?(self.content_type)
      end

      # Ensure source is valid, and if not, update the ActiveRecord errors object with the source error.
      def valid_source?
        message = if source.nil?
          "Source not available"
        else
          source.error unless source.valid?
        end
        field = @url ? :url : (@file ? :file : :source)
        errors.add(field, message) if message
      end

      # Process the source and load the resulting metadata.  No processing of the primary attachment should impede the creation of aspects.
      def process!
        if source && @source_updated && source.valid? && processing
          logger.debug "Attach: PROCESSING     #{self} (#{source} @ #{source.uri}) with #{processing}\n"
          self.source = Sources::Base.process(source, processing)
        end
        true
      end

      # Returns true if the original attachment or any of its aspects require data for processing (best guess) or storing.
      # Manually defined _aspects (via attribute) are assumed to not require data for processing unless the store attribute is also set.
      def data_required?
        store || image? && _aspects.any? do |name, attributes|
          attributes.nil? ? Sources::Base::AvailableImageProcessing.include?(name) : attributes[:store]
        end
      end

      # Returns the specific processing required for this Attachment instance
      def processing
        @processing ||= image? && (resize ? :max : :info)
      end

      # Create additional child attachments for each requested aspect.  Processing rules are
      # converted to attributes as required and the queue is cleared when complete.
      def create_aspects
        _aspects.inject({}) { |m,(k,v)| m[k] = v || {:processing => k, :source => source}; m }.each do |name, attrs|
          aspects.make(name, attrs)
        end
        _aspects.clear
      end

      # Store the attachment to the backend, if required, and trigger associated callbacks.
      # Sources are saved to the location identified by the uri attribute if the store attribute is set.
      def save_source
        raise "No source provided" unless source
        return unless @source_updated
        if store || !source.persistent?
          storage_uri = self.class.storage_uri(uuid!, aspect, mime_type)
          logger.debug "Attach: SAVE SOURCE    #{self} (#{source} @ #{source.uri}) to #{storage_uri}\n"
          self.source = Sources::Base.store(source, storage_uri)
        end
        self.uri = source.uri # Remember the attachment source
        @source_updated = nil # Indicate that no further storage is necessary.
      end

      def destroy_source
        source && source.destroy
      rescue MissingSource
        true # If the source is missing, carry on.
      ensure
        @source = nil
      end

      private
      def cgi_metadata(data)
        returning(Hash.new) do |md|
          md[:filename] = data.original_filename if data.respond_to?(:original_filename)
          md[:mime_type] = ::Mime::Type.lookup(data.content_type) if data.respond_to?(:content_type)
        end
      end

      # Extract stored metadata from attributes to enrichen a purely binary source to the same level as a CGI-supplied source.
      def stored_metadata
        %w(filename mime_type).inject(Hash.new) {|hash, key| hash[key.to_sym] = self.send(key.to_sym);hash}
      end
    end

    module AspectsAssociation
      def make(name, attrs)
        raise(AspectError.new("Can't create an aspect of an aspect")) unless proxy_owner.parent_id.nil?
        logger.debug "Attach: MAKE ASPECT   #{proxy_owner}->#{name}\n"
        with_exclusive_scope do
          create!(attrs.merge({:aspect => name.to_s}))
        end
      end
    end
  end
end