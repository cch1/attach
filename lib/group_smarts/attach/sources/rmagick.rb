require 'RMagick'
module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for attachments modified by RMagick
      class Rmagick < GroupSmarts::Attach::Sources::Base
        StandardImageGeometry = { :thumbnail => ::Magick::Geometry.from_s("128x128"), 
                                  :vignette => ::Magick::Geometry.from_s('256x256'), 
                                  :proof => ::Magick::Geometry.from_s('512x512'),
                                  :max => ::Magick::Geometry.from_s('2097152@')} # 2 Megapixels
        def initialize(source)
          super
          @source = source
          @uri = @source.uri
          @blob = @source.blob
        end
        
        # Process this source with the given transformation, which must be a Geometry object.
        def process(transform)
          case transform
            when :thumbnail, :vignette, :proof, :max
              image.change_geometry(StandardImageGeometry[transform.to_sym]) { |cols, rows, image| image.resize!(cols, rows) }
              @aspect = transform.to_s
              @uri = nil # Once transformed, all external sources are invalid.
              @blob = nil # Once transformed, we need to reset the data.  Now the getter can lazily load the blob.
              self
            else raise "Don't know how to do the #{transform} transformation" 
          end
        end

        # =Metadata=
        # Gets a filename suitable for this attachment.  
        def filename
          adjusted_filename_for(@source.filename, @aspect)          
        end
        
        def uri
          @uri ||= super
        end
        
        # Return size of source in bytes.  
        # NB: The filesize method is stale after resize/thumbnail until to_blob is invoked (or perhaps other methods).
        def size
          data
          image.filesize
        end
        
        # Return content type of source as a string.
        def mime_type
          ::Mime::Type.lookup(image.mime_type)
        end
        
        def metadata
          returning super.merge(exif_data) do |h|
            h[:height] = image.rows
            h[:width] = image.columns
          end
        end
        
        # =Data=
        # Return the source's data as a blob string.
        def blob
          @blob ||= image.to_blob
        end

        # Return the source's data as a tempfile.
        def tempfile
          @tempfile ||= returning(::Tempfile.new(filename, GroupSmarts::Attach.tempfile_path)) do |t|
            t.close
            image.write(t.path)
          end
        end
        
        def image
          @image ||= ::Magick::Image.read(@source.tempfile.path).first
        end

        private
        # Adjust filename for being a thumbnail:  'foo.jpg' becomes 'foo_thumbnail.jpg'
        def adjusted_filename_for(filename, aspect = nil)
          return filename if aspect.blank?
          ext = nil
          basename = filename.gsub /\.\w+$/ do |s|
            ext = s; ''
          end
          "#{basename}_#{aspect}#{ext}"
        end

        # Extract useful information from (ExiF | IPTC) header, if possible.  
        def exif_data
          @exif_data ||= returning Hash.new do |data|
            begin
              if (timestamp = (image.get_exif_by_entry('DateTime').first.last || image.get_exif_by_entry('DateTimeOriginal').first.last))
                # Replace colons and forward slashes in the first (date) portion of the string with dashes.
                timestamp.gsub!(/^\d+(:|\/)\d+(:|\/)\d+/) {|s| s.gsub(/:|\//, '-')}
                data[:time] = DateTime.parse(timestamp)
              end
      #        if (location = (img.get_exif_by_entry('location').first.last || img.get_exif_by_entry('location').first.last))
      #          data[:location] = Location.parse(location)
      #        end
            rescue # returning block will return data hash as it was before the exception.
            end
          end
        end
      end
    end
  end
end