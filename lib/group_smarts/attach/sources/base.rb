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
        attr_reader :error
        
        def initialize(*args)
        end
        
        def valid?
          error.nil?
        end
        
        # Load the source data/metadata. 
        def load!(full = true)
          true
        end
        
        # Return size of source in bytes.
        def size
          data.size  
        end

        # Return the MD5 digest of the source
        def digest
          Digest::MD5.digest(data)
        end

        # Return available metadata.
        def metadata
          returning Hash.new do |h|
            h[:size] = size
            h[:digest] = digest
          end
        end
        
        # Return an IO-compatible instance with source's data.
        def io
          StringIO.new(data || "", 'rb')
        end
        
        # Return the source's data as a blob string
        def data
          ""
        end
        
        # Return a Tempfile with source's data.
        def tempfile
          returning Tempfile.new(filename, GroupSmarts::Attach.tempfile_path) do |tmp|
            tmp.binmode
            tmp.write(data)
            tmp.close
          end          
        end
        
        private
        # Return a filename suitable for holding this source's data.
        def filename
          "#{'attachment'}#{rand Time.now.to_i}"
        end
      end
    end
  end
end