module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for IO-based sources.
      class IO < Hapgood::Attach::Sources::Base
        # Does this source persist at the URI independent of this application?
        def persistent?
          false
        end

        # Can this source be modified by this application?
        # This assumes a read-only IO channel.
        def readonly?
          true
        end

        # =Metadata=

        # =Data=
        # Returns the rewound IO instance that we are proxying.
        def io
          @data
        end

        # Returns the source's data as a blob string.  WARNING: Performance problems can result if the source is large
        def blob
          io.read
        end
      end
    end
  end
end