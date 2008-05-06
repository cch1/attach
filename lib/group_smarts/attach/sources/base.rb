module GroupSmarts # :nodoc:
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
        attr_reader :error, :data
        
        # Loads data from a primary source with bonus/primer metadata.  Primary sources can be either rich sources (capable of supplying raw 
        # attachment data and metadata) or simple sources (only able to provide raw data).  Every storage source should also be a primary source. 
        def self.load(raw_source = nil, metadata = {})
          case raw_source
            when ::URI  # raw source is actually a reference to an external source
              case raw_source.scheme
                when 'http', 'https' then Sources::Http.new(raw_source, metadata)
                when 'db' then Sources::ActiveRecord.new(raw_source, metadata)
                when 'file', NilClass
                  f = ::File.open(URI.decode(raw_source.path), "r+b")
                  Sources::File.new(f, metadata)
                when 's3' then Sources::S3.new(raw_source, metadata)
                else raise "Source for scheme '#{raw_source.scheme}' not supported."
              end
            when File then Sources::File.new(raw_source, metadata)
            when Tempfile, ActionController::TestUploadedFile then Sources::Tempfile.new(raw_source, metadata)
            when IO then Sources::IO.new(raw_source, metadata)
            when String then Sources::Blob.new(raw_source, metadata)
            when nil then self.new
            else raise "Don't know how to load #{raw_source.class}."
          end
        end
        
        # Process the given source with the given transformation.
        def self.process(source, transform = :identity)
          transform = transform.to_sym
          case transform
            when :iconify then Sources::Http.new(::URI.parse('http://www.iconspedia.com/uploads/1537420179.png'))
#              when :thumbshot then Source::Thumbshooter.new(source).process()
#              when :sample then Source::MPEGSampler.new(source).process()
            when :thumbnail, :vignette, :proof, :max
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
          store = case uri.scheme
#            when 'http', 'https' then Sources::Http.new(uri)   # Need ARes to pull this off...
            when 'file' then Sources::File.new(uri)
#            when 's3' then Sources::S3.new(uri)
            when 'db' then Sources::ActiveRecord.new(uri)
            else raise "Don't know how to store to #{uri}."
          end
          returning store do |s|
            s.store(source)
          end
        end
        
        def initialize(d = nil, m = nil)
          @data = d # Store primer data
          @metadata = m || {} # Store primer metadata
        end
        
        def valid?
          error.nil?
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
          returning ::Tempfile.new(filename, GroupSmarts::Attach.tempfile_path) do |tmp|
            tmp.binmode
            tmp.write(blob)
            tmp.close
          end          
        end
      end
    end
  end
end