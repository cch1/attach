module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      class LocalAsset < GroupSmarts::Attach::Sources::File
        attr_reader :uri
        def initialize(uri, m = {})
          super
          @uri = @data
        end

        # =Metadata=
        # Returns a filename suitable for naming this attachment.
        def filename
          fn.split('/')[-1]
        end

        # Returns the size of the source in bytes.
        def size
          ::File.size fn
        end
        
        private
        # Returns the absolute path of the asset
        def fn
          ::File.join(RAILS_ROOT, 'public', uri.path) 
        end
        
        def file
          ::File.open(fn)
        end
      end
    end
  end
end