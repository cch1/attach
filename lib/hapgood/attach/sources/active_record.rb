module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed, persistent sources/sinks
      class ActiveRecord < Hapgood::Attach::Sources::Base
        # Create a new record and store the given source in it.
        def self.store(source, uri)
          db_file = AttachmentBlob.create(:blob => source.blob)
          self.new(db_file, source.metadata)
        end

        # Reload a persisted source
        def self.reload(uri, metadata = {})
          dbid = uri.path.split('/')[-1]
          db_file = AttachmentBlob.find(dbid)
          self.new(db_file, metadata)
        end

        # =State Transitions=
        # Destroy this source/sink and return a new instance of the base source.
        def destroy
          @data.destroy
          super
          # Nothing further to do: ActiveRecord association's :dependent option takes care of cleaning up blob.
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          true
        end

        # Can this source be modified by this application?
        def readonly?
          false
        end

        # =Metadata=
        def uri
          URI.parse("db:/#{@data.id}")
        end

        # =Data=
        # Return blob of data
        def blob
          @data.blob
        end
      end
    end
  end
end