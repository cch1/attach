module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed, persistent sources/sinks
      class ActiveRecord < GroupSmarts::Attach::Sources::Base
        attr_reader :uri
        def initialize(uri, m = {})
          super
          @uri = @data
        end
        
        # =State Transitions=
        # Save this source to its persistent storage
        def store(source)
          @metadata = source.metadata # Assume the source's metadata
          dbf.blob = source.blob
          dbf.save!
        end

        # Destroy this source/sink and return a new instance of the base source.
        def destroy
          super
          # Nothing further to do: ActiveRecord association's :dependent option takes care of cleaning up blob.
        end
        
        # =Metadata=
        # None beyond the crude calculations in Base.
        
        # =Data=
        # Return blob of data
        def blob
          dbf.blob
        end
        
        private
        # Get this source from its persistent storage
        def id
          @id ||= uri.path.split('/')[-1]
        end
        
        def dbf
          @dbf ||= ::AttachmentBlob.find_by_attachment_id(id) || ::AttachmentBlob.new(:attachment_id => id)
        end
      end
    end
  end
end