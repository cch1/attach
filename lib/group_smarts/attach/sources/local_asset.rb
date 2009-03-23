module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      class LocalAsset < GroupSmarts::Attach::Sources::File
        # =Metadata=
        def uri
          @data
        end

        # =State Transitions=
        def destroy
          # Do nothing -a local asset should outlive any referencing source and its associated attachment.
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