require 'hapgood/attach/sources'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    @@image_content_types = ['image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/x-png', 'image/jpg', 'image/bmp']
    mattr_reader :image_content_types

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
      # *  <tt>:store</tt> - A proc that takes three arguments (id, aspect and extension) and returns a storage URI.
      #
      # Examples:
      #   has_attachment :max_size => 1.kilobyte
      #   has_attachment :size => 1.megabyte..2.megabytes
      #   has_attachment :content_type => 'application/pdf'
      #   has_attachment :content_type => ['application/pdf', 'application/msword', 'text/plain']
      #   has_attachment :content_type => :image, :resize_to => [50,50]
      #   has_attachment :content_type => ['application/pdf', :image], :resize_to => 'x50'
      def has_attachment(options = {})
        # this allows you to redefine the acts' options for each subclass, however
        options[:min_size]         ||= 1
        options[:max_size]         ||= 1.megabyte
        options[:size]             ||= (options[:min_size]..options[:max_size])
        options[:s3_access]        ||= :public_read
        options[:content_type] = [options[:content_type]].flatten.collect! { |t| t == :image ? Hapgood::Attach.image_content_types : t }.flatten unless options[:content_type].nil?
        options[:store]            ||= Proc.new {|i, e| "file://localhost#{::File.join(RAILS_ROOT, 'public', 'attachments', [i,e].compact.join('.'))}"}

        # doing these shenanigans so that #attachment_options is available to processors and backends
        class_inheritable_accessor :attachment_options
        self.attachment_options = options

        # only need to define these once on a class
        unless included_modules.include?(InstanceMethods)
          attr_accessor :resize
          attr_accessor :store  # indicates whether or not to store attachment data.  Set to false to not store data and instead use a remote reference
          attr_writer :processing # Queue of transformations to apply to the attachment.

          delegate :blob, :public_uri, :processable?, :to => :source

          before_validation :process!
          before_save :save_source
          after_destroy :destroy_source
          extend  ClassMethods
          include InstanceMethods
        end
      end
    end

    module ClassMethods
      delegate :image_content_types, :to => Hapgood::Attach

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
      def storage_uri(id, mt)
        extension = mt.to_sym.to_s.gsub('/', '_') rescue nil
        ::URI.parse(attachment_options[:store].call(id, extension))
      end
    end

    module InstanceMethods
      # Checks whether the attachment's content type is an image content type
      def image?
        self.class.image?(content_type)
      end

      # Returns predicate based on attachment being hosted locally (will be stored locally or already stored locally)
      # OPTIMIZE: Consider having this be a method on source for encapsulation.
      def local?
        !(source.kind_of?(Sources::Http) && !store)
      end

      # Getter for file virtual attribute for consistency with setter.  Useful in case this field is used in a form.
      def file() nil; end

      # Setter for the (uploaded) file.
      def file=(upload)
        return unless upload
        destroy_source  # Discard any existing source
        begin
          self.source = Sources::Base.load(upload, cgi_metadata(upload))
        rescue => e  # Can't do much here -we have to wait until the validation phase to resurrect/reconstitute errors
          logger.error("Attach: *********ERROR: can't load uploaded file (#{e})")
        end
      end

      # Getter for url virtual attribute for consistency with setter.  Useful in case this field is used in a form.
      def url
        @url ||= source.kind_of?(Sources::Http) ? uri.to_s : nil
      end

      # Setter for virtual url attribute used to reference external data sources.
      def url=(u)
        @url = u
        return unless u
        destroy_source  # Discard any existing source
        begin
          self.source = Sources::Base.load(::URI.parse(u))
        rescue => e  # Can't do much here -we have to wait until the validation phase to resurrect/reconstitute errors
          logger.error("Attach: *********ERROR: can't load url (#{e})")
        end
      end

      # Get the source.  Rescue exceptions and make them errors on the source virtual attribute.
      def source
        @source ||= uri && Sources::Base.reload(uri, stored_metadata)
      end

      # Set the source.  Note that the current source *will be destroyed* where persisted and not read-only.
      def source=(src)
        raise "Source should be an instance of Attach::Sources::Base or its subclasses." unless src.kind_of?(Sources::Base)
        raise "Source is not valid." unless src.valid?
        destroy_source if @source && (@source.persistent? && !@source.readonly?)
        self.metadata = src.metadata.reject{|k,v| respond_to?("#{k}=")}
        self.attributes = src.metadata.reject{|k,v| !respond_to?("#{k}=")}
        @source = src
        @source_updated = true
      end

      # Allows you to work with a processed representation (RMagick, ImageScience, etc) of the attachment in a block.
      # The source is modified to reflect modifications to the image.
      #   @attachment.change_image do |img|
      #     img.thumbnail(100, 100)
      #   end
      def change_image(&block)
        self.source = source.change_image(&block)
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

      # Returns the specific processing required for this Attachment instance
      def processing
        @processing ||= image? && (resize ? :max : :info)
      end

      # Store the attachment to the backend, if required.
      # Sources are saved to the location identified by the uri attribute if the store attribute is set.
      def save_source
        raise "No source provided" unless source
        return unless @source_updated
        if store || !source.persistent?
          storage_uri = self.class.storage_uri(uuid!, mime_type)
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
        Hash.new.tap do |md|
          md[:filename] = data.original_filename if data.respond_to?(:original_filename)
          md[:mime_type] = ::Mime::Type.lookup(data.content_type) if data.respond_to?(:content_type)
        end
      end

      # Extract stored metadata from attributes to enrichen a purely binary source to the same level as a CGI-supplied source.
      def stored_metadata
        %w(filename mime_type).inject(Hash.new) {|hash, key| hash[key.to_sym] = self.send(key.to_sym);hash}
      end
    end
  end
end