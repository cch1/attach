require 'hapgood/attach/sources/base'
require 'exifr'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for attachments processed (read-only) by EXIFR
      class EXIFR < Hapgood::Attach::Sources::Base
        def initialize(source)
          super
          @source = source
        end

        # Process this source with the given transformation.  This source can only augment the metadata so we return ourself here.
        def process(transform)
          self
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          @source.persistent?
        end

        # Can this source be modified by this application?
        def readonly?
          @source.readonly?
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
          super().tap do |h|
            h.reverse_merge!(image.exif.to_hash) if image.exif?
            h[:height] = image.height if image.height
            h[:width] = image.width if image.width
            h[:time] = h.delete(:date_time_original) || h.delete(:date_time)
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
            when :jpg, :tif then ::EXIFR::JPEG.new(@source.tempfile.path)
            else raise "Can't process source with MIME type #{mime_type}."
          end
        end
      end
    end
  end
end