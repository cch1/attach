require 'hapgood/attach/sources/base'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for blob sources
      class Blob < Hapgood::Attach::Sources::Base
        # Does this source persist at the URI independent of this application?
        def persistent?
          false
        end

        # Can this source be modified by this application?
        def readonly?
          false
        end

        # =Metadata=

        # =Data=
        # Return the source's data as a blob.
        def blob
          @data
        end
      end
    end
  end
end