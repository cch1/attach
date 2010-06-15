module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Abstract class for attachment sources.  All subclasses should implement:
      #   uri             : A relative or absolute URI representing the attachment
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
          case raw_source
            when ::ActionController::UploadedStringIO then Sources::IO.new(raw_source, metadata)
            when ::ActionController::UploadedTempfile then Sources::Tempfile.new(raw_source, metadata)
            when ::URI  # raw source is actually a reference to an external source
              case raw_source.scheme
                when 'http', 'https' then Sources::Http.new(raw_source, metadata)
                when nil then Sources::LocalAsset.new(raw_source, metadata)
                else raise "Source for scheme '#{raw_source.scheme}' not supported for loading."
              end
            when ::File then Sources::File.new(raw_source, metadata)
            when ::Tempfile then Sources::Tempfile.new(raw_source, metadata)
            when ::IO then Sources::IO.new(raw_source, metadata)
            when ::String then Sources::Blob.new(raw_source, metadata)
            when nil then self.new
            when defined?(::ActionController::TestUploadedFile) && ::ActionController::TestUploadedFile then Sources::Tempfile.new(raw_source, metadata)
            else
              raise "Don't know how to load #{raw_source.class}."
          end
        end

        def self.reload(uri, metadata = {})
          case uri.scheme
            when 'http', 'https' then Sources::Http.new(uri, metadata)
            # Following operations use URI to load a persisted source from storage
            when 'db' then Sources::ActiveRecord.reload(uri, metadata)
            when 'file' then Sources::File.reload(uri, metadata)
            when 's3' then Sources::S3.reload(uri, metadata)
            when nil then Sources::LocalAsset.new(uri, metadata)
            else raise "Source for scheme '#{uri.scheme}' not supported for reloading."
          end
        end

        # Process the given source with the given transformation.
        def self.process(source, transform = :identity)
          transform = transform.to_sym
          case transform
            when :icon then Sources::LocalAsset.new(::URI.parse(icon_path(source.mime_type)))
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
          case uri.scheme
#            when 'http', 'https' then Sources::Http.new(uri)   # Need ARes to pull this off...
            when 'file', nil then Sources::File.store(source, uri) # nil implies local storage in a relative path
            when 's3' then Sources::S3.store(source, uri)
            when 'db' then Sources::ActiveRecord.store(source, uri)
            else raise "Don't know how to store to #{uri}."
          end
        end

        def self.icon_path(mt)
          name = mt.to_s.gsub('/', '_')
          image_path("mime_type_icons/#{name}.png")
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
        # Return ::URI representing where this source is available.
        def uri
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