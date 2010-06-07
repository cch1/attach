module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for Tempfile-based primary sources.
      class Tempfile < Hapgood::Attach::Sources::File
        # =Metadata=
        # Returns the URI of the source.
        def uri
          nil
        end
        
        # =Data=
        # Trivial short-circuit that returns the tempfile itself.
        def tempfile
          @data
        end
      end
    end
  end
end