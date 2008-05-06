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
        
        # Process this source with the given transformation.  This source can only augment the metadata so we return ourself here.
        def process(transform)
          self
        end

        # =Metadata=        
        def mime_type
          @source.mime_type
        end
        
        def filename
          @source.filename
        end
        
        def uri
          @source.uri
        end
        
        def metadata
          returning super do |h|
            h[:height] = image.height if image.height
            h[:width] = image.width if image.width
            h[:time] = image.date_time if image.date_time
          end
        end
        
        # =Data=
        # Return the source's data.
        def blob
          @source.blob
        end

        private        
        def image
          @image ||= case mime_type.to_sym
            when :jpg, :tif then ::EXIFR::JPEG.new(@source.io)
            else raise "Can't process source with MIME type #{mime_type}."
          end
        end
      end
    end
  end
end