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

        # Return size of source in bytes.
        def size
          @source.size  
        end
        
        # Return the IO-like object that we are proxying.
        def io
          @source
        end
        
        # Return the source's data.  WARNING: Performance problems can result if the source is large, remote or both.
        def data
          @source.rewind
          @source.read
        end
      end
    end
  end
end