require 'hapgood/attach/sources/base'
require 'RMagick' # The gem is rmagick, the library is RMagick and the namespace is Magick

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for attachments modified by RMagick
      class Rmagick < Hapgood::Attach::Sources::Base
        # The ImageMagick format string that maps to the given Mime::Type
        def self.format_for_mime_type(mt)
          @format_for_mime_type ||= begin
            # Unfortunately, the support mask returned by Magick.formats is unreliable -otherwise we would winnow with =~ /.r../
            recognized_formats = ::Magick.formats.keys.select{|fmt| Mime::EXTENSION_LOOKUP.keys.include?(fmt.downcase)}
            recognized_formats.inject({}){|m, fmt| m[Mime::EXTENSION_LOOKUP[fmt.downcase]] = fmt;m }
          end
          @format_for_mime_type[mt]
        end

        def self.processable?(mime_type)
          !!format_for_mime_type(mime_type)
        end

        def initialize(source)
          super
          @source = source
          @uri = @source.uri
          @blob = @source.blob
          @persistent = @source.persistent?
        end

        # Process this source with the given transformation, which must be a Geometry object.
        def process(transform)
          raise "Don't know how to do the #{transform} transformation" unless geometry = StandardImageGeometry[transform.to_sym]
          change_image do |img|
            img.change_geometry(geometry) { |cols, rows, image| image.resize!(cols, rows) }
          end
          @aspect = transform.to_s
          self
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          @persistent
        end

        # Can this source be modified by this application?
        def readonly?
          false
        end

        # =Metadata=
        # Gets a filename suitable for this attachment.
        def filename
          pn = Pathname.new(@source.filename)
          pn.basename(pn.extname).to_s.tap do |s|
            s << "_" << @aspect unless @aspect.nil?
            s << "." << mime_type.to_sym.to_s
          end
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
          super.merge(exif_data).tap do |h|
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
          @tempfile ||= ::Tempfile.new(filename, tempfile_path).tap do |t|
            t.close
            image.write(t.path)
          end
        end

        def image
          @image ||= begin
            format = self.class.format_for_mime_type(@source.mime_type)
            read_spec = "#{@source.tempfile.path}[0]"
            read_spec = "#{format}:" + read_spec if format
            ::Magick::Image.read(read_spec).first
          end
        end

        # Change the image within the block
        def change_image(&block)
          yield image
          @tempfile = nil
          @uri = nil # Once transformed, all external sources are invalid.
          @blob = nil # Once transformed, we need to reset the data.  Now the getter can lazily load the blob.
          @persistent = false
          self
        end

        private
        # Extract useful information from (ExiF | IPTC) header, if possible.
        def exif_data
          @exif_data ||= Hash.new.tap do |data|
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