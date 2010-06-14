module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for Tempfile-based primary sources.
      class Tempfile < Hapgood::Attach::Sources::File
        # Does this source persist at the URI independent of this application?
        def persistent?
          false
        end

        # Can this source be modified by this application?
        def readonly?
          false
        end

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