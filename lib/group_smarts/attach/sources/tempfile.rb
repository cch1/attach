module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for Tempfile-based primary sources.
      class Tempfile < GroupSmarts::Attach::Sources::File
        # =Metadata=
        # Returns the URI of the source.
        def uri
          nil
        end
        
        # =Data=
        # Trivial short-circuit that returns the rewind tempfile itself.
        def tempfile
          @data.rewind
          @data
        end
      end
    end
  end
end