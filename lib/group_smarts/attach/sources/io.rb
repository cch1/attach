module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for IO-based sources.
      class IO < GroupSmarts::Attach::Sources::Base
        # =Metadata=
        # Augment metadata hash
        def metadata
          returning super do |h|
            h[:size] = size
            h[:digest] = digest
          end
        end

        # =Data=
        # Returns the rewound IO instance that we are proxying.
        def io
          @data.rewind
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