module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed File sources/sinks.
      class File < GroupSmarts::Attach::Sources::IO
        BASE_URI = ::URI.parse('file://localhost/')
        def initialize(file, metadata)
          super
          @file = @data
          @io = @file
        end
        
        # =Metadata=
        # Construct a URI using the file scheme.
        def uri
          @uri ||= BASE_URI.merge(URI.encode(@file.path)).normalize
        end

        # Augment metadata hash
        def metadata
          returning super do |h|
#            h[:uri] = uri
          end
        end
        
        # =Data=
        # Returns a closed Tempfile of source's data.
        def tempfile
          returning Tempfile.new(filename, GroupSmarts::Attach.tempfile_path) do |tmp|
            tmp.close
            FileUtils.cp file, tmp.path
          end
        end
      end
    end
  end
end