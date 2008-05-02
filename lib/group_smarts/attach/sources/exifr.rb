require 'exifr'
module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for attachments processed (read-only) by EXIFR
      class EXIFR < GroupSmarts::Attach::Sources::Base
        def initialize(source)
          super
          @source = source
        end
        
        # Process this source with the given transformation.
        def process(transform)
          print "Transforming with #{transform}\n"
        end

        # =Metadata=        
        def metadata
          returning super do |h|
            h[:height] = image.height
            h[:width] = image.width
          end
        end
        
        # =Data=
        # Return the source's data.
        def data
          @source.data
        end

        private        
        def image
          @image ||= case @source.mime_type
            when ::Mime::Type.lookup('image/jpeg') then ::EXIFR::JPEG.new(@source.io)
            else raise "Can't process source with MIME type #{@source.mime_type}."
          end
        end
      end
    end
  end
end