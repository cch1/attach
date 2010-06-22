require 'hapgood/attach/sources/rmagick'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Abstract class for attachment sources.  All subclasses should implement:
      #   uri             : A relative or absolute URI representing the attachment's persistent storage
      #   public_uri      : A relative or absolute URI representing where the attachment is available via the http(s) scheme.
      #   size            : The size of the attachment in bytes
      #   digest          : The MD5 digest of the attachment data
      #   content_type    : The MIME type of the attachment, as a string.
      #   metadata        : A hash of all metadata available.
      #   io              : An IO-compatible object of the attachment's data
      #   data            : A blob (string) of the attachment's data
      #   tempfile        : A tempfile of the attachment
      class Base
        class_inheritable_accessor :tempfile_path, :instance_writer => false
        write_inheritable_attribute(:tempfile_path, File.join(RAILS_ROOT, 'tmp', 'attach'))

        AvailableImageProcessing = Sources::Rmagick::StandardImageGeometry.keys

        attr_reader :error, :data

        extend ActionView::Helpers::AssetTagHelper

        # Loads data from a primary source with bonus/primer metadata.  Primary sources can be either rich sources (capable of supplying raw
        # attachment data and metadata) or simple sources (only able to provide raw data).  Every storage source should also be a primary source.
        def self.load(raw_source = nil, metadata = {})
          klass = case raw_source
            when ::URI  # raw source is actually a reference to an external source
              case raw_source.scheme
                when 'http', 'https' then Sources::Http
                else raise "Source for scheme '#{raw_source.scheme}' not supported for loading."
              end
            when ::Pathname then Sources::LocalAsset
            when ::File then Sources::File
            when ::Tempfile, ::ActionController::UploadedTempfile then Sources::Tempfile
            when ::IO, ::ActionController::UploadedStringIO then Sources::IO
            when ::String then Sources::Blob
            when defined?(::ActionController::TestUploadedFile) && ::ActionController::TestUploadedFile then Sources::Tempfile
            else
              raise "Don't know how to load #{raw_source.class}."
          end
          klass.load(raw_source, metadata)
        end

        def self.reload(uri, metadata = {})
          klass = case uri.scheme
            when 'http', 'https' then Sources::Http
            when 'db' then Sources::ActiveRecord
            when 'file' then Sources::File
            when 's3' then Sources::S3
            when 'memory' then Sources::Memory
            when nil then Sources::LocalAsset
            else raise "Source for scheme '#{uri.scheme}' not supported for reloading."
          end
          klass.reload(uri, metadata)
        end

        # Process the given source with the given transformation.
        def self.process(source, transform = :identity)
          transform = transform.to_sym
          case transform
            when :icon then Sources::LocalAsset.load(icon_path(source.mime_type))
#              when :thumbshot then Source::Thumbshooter.new(source).process()
#              when :sample then Source::MPEGSampler.new(source).process()
            when *Sources::Rmagick::StandardImageGeometry.keys
              returning(Sources::Rmagick.new(source)) {|s| s.process(transform) }
            when :info
              case source.mime_type.to_sym
                when :jpg, :tiff then Sources::EXIFR.new(source).process(transform)
                else source # No additional information available.
              end
            else raise "Don't know how to do #{transform} transform."
          end
        end

        # Store the given source at the given URI.
        def self.store(source, uri)
          klass = case uri.scheme
            when 'file' then Sources::File
            when 's3' then Sources::S3
            when 'db' then Sources::ActiveRecord
            when 'memory' then Sources::Memory
            else raise "Don't know how to store to #{uri}."
          end
          klass.store(source, uri)
        end

        def self.icon_path(mt)
          name = mt.to_s.gsub('/', '_')
          Pathname.new(ActionView::Helpers::AssetTagHelper::ASSETS_DIR).join('images', 'mime_type_icons', "#{name}.png")
        end

        def initialize(d = nil, m = nil)
          @data = d # Store primer data
          @metadata = m || {} # Store primer metadata
        end

        def valid?
          error.nil?
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          raise "Not yet implemented"
        end

        # Can this source be modified by this application?
        def readonly?
          raise "Not yet implemented"
        end

        # Destroy this source.
        def destroy
          @data = nil
          @metadata = nil
          freeze
        end

        # =Metadata=
        # Return ::URI representing where this source is persisted.
        def uri
          nil
        end

        # Return ::URI where this attachment is available via http
        def public_uri
          nil
        end

        # Return the ::Mime::Type for this this attachment.
        def mime_type
          @metadata[:mime_type]
        end

        # Return a reasonable filename for this source
        def filename
          @metadata[:filename] || "attachment"
        end

        # Return size of source in bytes.
        def size
          blob.size
        end

        # Return the MD5 digest of the source
        def digest
          Digest::MD5.digest(blob)
        end

        # Return all available metadata.
        def metadata
          returning @metadata do |h|
            #  This represents the minimal set of attribute methods that should be available in every subclass.
            h[:mime_type] = mime_type if mime_type
            h[:filename] = filename if filename
            h[:digest] = digest if digest
            h[:size] = size if size
          end
        end

        # =Data=
        # Return an IO-compatible instance with source's data.
        def io
          @io ||= StringIO.new(blob, 'r+b')
        end

        # Return the source's data as a blob string
        def blob
          nil
        end

        # Return a closed Tempfile of source's data.
        def tempfile
          returning(::Tempfile.new(filename, tempfile_path)) do |tmp|
            tmp.binmode
            tmp.write(blob)
            tmp.close
          end
        end
      end
    end
  end
end