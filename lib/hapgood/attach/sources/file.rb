require 'fileutils'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed File sources/sinks.
      class File < Hapgood::Attach::Sources::IO
        FMASK = 0644
        DMASK = 0755

        attr_reader :uri

        def self.load(file, metadata = {})
          uri = URI.parse('file://localhost/').merge(::File.expand_path(file.path))
          self.new(uri, metadata)
        end

        # Create a new File at the given URI and store the given source in it.
        def self.store(source, uri)
          p = Pathname(uri.path)
          FileUtils.mkdir_p(p.dirname, :mode => DMASK)
          raise "Target file already exists! (#{p}) " if p.exist?
          FileUtils.cp(source.tempfile.path, uri.path)
          p.chmod(FMASK) if FMASK
          self.new(uri, source.metadata)
        end

        # Reload a persisted source
        def self.reload(uri, metadata = {})
          self.new(uri, metadata)
        end

        def initialize(uri, m = {})
          @uri = uri
          super
        end

        def valid?
          !!file
        rescue MissingSource => e
          @error = e.to_s
          false
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          true
        end

        # Can this source be modified by this application?
        def readonly?
          frozen? || !pathname.writeable?
        end

        # =Metadata=
        # Return ::URI where this attachment is available via http
        def public_uri
          pp = Pathname(uri.path).realpath.relative_path_from(Pathname.new(Rails.public_path).realpath)
          pp.to_s.match(/\.\./) ? nil : URI.parse("/" + pp)
        rescue ArgumentError
          nil # no public path exits
        end

        # Returns a file name suitable for this source when saved in a persistent file.
        # This is a fallback as the basename can be cryptic in many case.
        def filename
          @metadata[:filename] || pathname.basename.to_s
        end

        # As a fallback, guess at the MIME type of the file using the extension.
        def mime_type
          @metadata[:mime_type] || Mime::Type.lookup_by_extension(pathname.extname[1..-1])
        end

        # =Data=
        def blob
          io.rewind
          io.read
        end

        # Returns a closed Tempfile of source's data.
        def tempfile
          returning ::Tempfile.new(filename, tempfile_path) do |tmp|
            tmp.close
            ::FileUtils.cp(pathname.to_s, tmp.path)
          end
        end

        def io
          file
        end

        # =State Transitions=
        def destroy
          pathname.delete
        rescue Errno::ENOENT
        ensure
          freeze
        end

        private
        def pathname
          @pathname ||= Pathname.new(uri.path)
        end

        def file
          pathname.open
        rescue Errno::ENOENT => e
          raise MissingSource, e.to_s
        end
      end
    end
  end
end