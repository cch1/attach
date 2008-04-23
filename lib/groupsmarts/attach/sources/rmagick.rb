module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for attachments modified by RMagick
      class Rmagick < GroupSmarts::Attach::Sources::Base
        attr_reader :filename
        
        def initialize(img, original_source, thumbnail)
          super
          @img = img
          @filename = thumbnail_name_for(original_source.filename, thumbnail)
        end
        
        # Returns the data of this source as an IO-compatible object
        def io
          @io ||= StringIO.new(data, 'rb')
        end

        # Return size of source in bytes.  
        # NB: The filesize method is stale after resize/thumbnail until to_blob is invoked (or perhaps other methods).
        def size
          data
          @img.filesize
        end
        
        # Return content type of source as a string.
        def content_type
          @img.mime_type
        end
        
        # Return the MD5 digest of the source
        def digest
          Digest::MD5.digest(data)
        end
        
        # Return the source's data.
        def data
          @data ||= @img.to_blob
        end

        # Return the source's data as a tempfile.
        def tempfile
          t = Tempfile.new(filename, GroupSmarts::Attach.tempfile_path)
          t.close
          @tempfile ||= @img.write(t.path)
        end
        
        private
        # Gets the thumbnail name for a filename.  'foo.jpg' becomes 'foo_thumbnail.jpg'
        def thumbnail_name_for(filename, thumbnail = nil)
          return filename if thumbnail.blank?
          ext = nil
          basename = filename.gsub /\.\w+$/ do |s|
            ext = s; ''
          end
          "#{basename}_#{thumbnail}#{ext}"
        end
      end
    end
  end
end