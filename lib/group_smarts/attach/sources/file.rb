require 'fileutils'

module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed File sources/sinks.
      class File < GroupSmarts::Attach::Sources::IO
        FMASK = 0644
        DMASK = 0755
        # Create a new File at the given URI and store the given source in it. 
        def self.store(source, uri)
          p = Pathname(uri.path)
          FileUtils.mkdir_p(p.dirname, :mode => DMASK)
          raise "Target file already exists! (#{p}) " if p.exist?
          FileUtils.cp(source.tempfile.path, uri.path)
          p.chmod(FMASK) if FMASK
          self.new(p.open, source.metadata)
        end

        # Reload a persisted source
        def self.reload(uri, metadata = {})
          begin
            f = ::File.open(URI.decode(uri.path), "r+b")
          rescue Errno::ENOENT => e
            raise MissingSource, e.to_s
          end
          self.new(f, metadata)
        end

        # =Metadata=
        # Construct a URI using the file scheme.
        def uri
          @uri ||= URI.parse("file://localhost").merge(URI.parse(fn))
        end
        
        # Returns a file name suitable for this source when saved in a persistent file.
        # This is a fallback as the basename can be cryptic in many case.
        def filename
          @metadata[:filename] || ::File.basename(fn)
        end

        # As a fallback, guess at the MIME type of the file using the extension.
        def mime_type
          @metadata[:mime_type] || Mime::Type.lookup_by_extension(::File.extname(fn)[1..-1])
        end

        # =Data=
        def blob
          io.rewind
          io.read
        end

        # Returns a closed Tempfile of source's data.
        def tempfile
          returning ::Tempfile.new(filename, GroupSmarts::Attach.tempfile_path) do |tmp|
            tmp.close
            ::FileUtils.cp(fn, tmp.path)
          end
        end

        def io
          file
        end
        
        # =State Transitions=
        def destroy
          begin
            FileUtils.rm fn
          rescue Errno::ENOENT => e
            raise MissingSource, e.to_s
          ensure
            super
          end
        end

        private
        def fn
          @data.path
        end

        def file
          @data
        end
      end
    end
  end
end