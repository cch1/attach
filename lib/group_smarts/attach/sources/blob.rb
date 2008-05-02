module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for blob sources
      class Blob < GroupSmarts::Attach::Sources::Base
        # =Metadata=
        # Augment metadata hash
        def metadata
          # OPTIMIZE: Check for mismatches?
          returning super do |h|
            h[:size] = size
            h[:digest] = digest
          end
        end
        
        # =Data=
        # Return the source's data as a blob.
        def blob
          @data
        end
      end
    end
  end
end