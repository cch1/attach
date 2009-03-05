module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed, persistent sources/sinks
      class ActiveRecord < GroupSmarts::Attach::Sources::Base
        attr_reader :uri

        # Create a new record identified by the given URI and store the given source in it. 
        def self.store(source, uri)
          attachment_id = uri.path.split('/')[-1]
          db_file = AttachmentBlob.create(:attachment_id => attachment_id, :blob => source.blob)
          self.new(db_file, source.metadata)
        end
        
        # Reload a persisted source
        def self.reload(uri, metadata = {})
          attachment_id = uri.path.split('/')[-1]
          raise "Missing attachment blob!" unless db_file = AttachmentBlob.find_by_attachment_id(attachment_id)
          self.new(db_file, metadata)
        end

        # =State Transitions=
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
          @data ||= AttachmentBlob.find_by_attachment_id(id)
        end
      end
    end
  end
end