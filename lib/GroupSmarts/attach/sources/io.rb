module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for IO-based sources.
      class IO < GroupSmarts::Attach::Sources::Base
        # Squirrel away the source
        def initialize(source)
          super
          @source = source
        end

        # Return the IO-like object that we are proxying.
        def io
          @source
        end
        
        # Arbitrary name
        def filename
          "attachment"
        end
        
        # Return size of source in bytes.
        def size
          @source.size  
        end
        
        # Return the MD5 digest of the source
        def digest
          Digest::MD5.digest(data)
        end
        
        # Return the source's data.  WARNING: Performance problems can result if the source is large, remote or both.
        def data
          @source.rewind
          @source.read
        end

        # Return the source's data as a tempfile.  WARNING: Performance problems can result if the source is large, remote or both.
        def tempfile
          returning Tempfile.new(filename, GroupSmarts::Attach.tempfile_path) do |tmp|
            tmp.binmode
            tmp.write(data)
            tmp.close
          end
        end
      end
    end
  end
end