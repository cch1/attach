require 'fileutils'

module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed File sources/sinks.
      class File < GroupSmarts::Attach::Sources::IO
        def initialize(uri, metadata = {})
          @uri = uri
          super
        end
        
        def store(source)
          @metadata = source.metadata
          FileUtils.mkdir_p(::File.dirname(fn))
          # TODO: raise an exception if the file exists.
          ::FileUtils.cp(source.tempfile.path, fn)
        end
        # =Metadata=
        # Construct a URI using the file scheme.
        def uri
          @uri
        end
        
        def destroy
          begin
            FileUtils.rm fn
          rescue
            logger.info "Exception destroying  #{fn.inspect}: [#{$!.class.name}] #{$1.to_s}"
          ensure
            super
          end
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
        
        private
        def fn
          @fn ||= "#{@uri.path}.#{mime_type.to_sym}"
        end

        def file
          returning (@file || ::File.open(fn)) do |f|
            f.rewind
          end
        end
      end
    end
  end
end