require 'hapgood/attach/sources/base'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed, persistent sources/sinks
      class ActiveRecord < Hapgood::Attach::Sources::Base
        attr_reader :uri

        # Create a new record and store the given source in it.
        def self.store(source, uri)
          dbf = AttachmentBlob.create(:blob => source.blob)
          self.new(uri.merge(dbf.id.to_s), source.metadata)
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
          !!dbf
        rescue MissingSource => e
          @error = e.to_s
          false
        end

        # =State Transitions=
        # Destroy this source/sink and return a new instance of the base source.
        def destroy
          dbf.destroy
        rescue MissingSource
        ensure
          freeze
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          true
        end

        # Can this source be modified by this application?
        def readonly?
          frozen?
        end

        # =Metadata=
        # TODO: Add last_modified predicated on DB field presence

        # =Data=
        # Return blob of data
        def blob
          dbf.blob
        end

        private
        def pk
          uri.path.split('/')[-1]
        end

        def dbf
          @dbf ||= begin
            AttachmentBlob.find(pk)
          rescue ::ActiveRecord::RecordNotFound => e
            raise MissingSource, e.to_s
          end
        end
      end
    end
  end
end