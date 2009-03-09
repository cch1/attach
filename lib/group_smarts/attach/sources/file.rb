require 'fileutils'

module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed File sources/sinks.
      class File < GroupSmarts::Attach::Sources::IO
        # Create a new File at the given URI and store the given source in it. 
        def self.store(source, uri)
          FileUtils.mkdir_p(::File.dirname(uri.path))
          # TODO: raise an exception if the file exists.
          FileUtils.cp(source.tempfile.path, uri.path)
          self.new(::File.open(uri.path), source.metadata)
        end

        # Reload a persisted source
        def self.reload(uri, metadata = {})
          f = ::File.open(URI.decode(uri.path), "r+b")
          self.new(f, metadata)
        end

        # =Metadata=
        # Construct a URI using the file scheme.
        def uri
          @uri ||= URI.parse("file://localhost").merge(URI.parse(file.path))
        end
        
        # Returns a file name suitable for this source when saved in a persistent file.
        # This is a fallback as the basename can be cryptic in many case.
        def filename
          @metadata[:filename] || ::File.basename(file.path)
        end

        # =Data=
        def blob
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
          rescue => e
            Rails.logger.info "Exception destroying  #{fn.inspect}: [#{$!.class.name}] #{$1.to_s}"
            raise e
          ensure
            super
          end
        end

        private
        def fn
          uri.path
        end

        def file
          @data.rewind
          @data
        end
      end
    end
  end
end