require 'hapgood/attach/sources/base'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed volatile memory sources/sinks.
      class Memory < Hapgood::Attach::Sources::Base
        # Expose the store for testing purposes
        cattr_accessor :_store
        @@_store = Hash.new
        attr_reader :uri

        # Create a new memory object at the given URI and store the given source in it.
        def self.store(source, uri)
          key = uri.path.split('/')[-1]
          raise "Target object already exists! (#{key}) " if _store.has_key?(key)
          _store[key] = source.blob
          self.new(uri, source.metadata)
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
          _store.has_key?(key) || (@error = "No such key in store #{key}" && false)
        end

        # Does this source persist at the URI independent of this application?
        # WARNING: This fallacy is required in order to use this source as a mock for testing.
        def persistent?
          true
        end

        # Can this source be modified by this application?
        def readonly?
          false
        end

        # =Metadata=
        # Returns a file name suitable for this source when saved in a persistent file.
        # The URI fallback is likely to be cryptic in many case.
        def filename
          @metadata[:filename] || uri.path.split('/')[-1]
        end

        # As a fallback, guess at the MIME type of the file using the extension.
        def mime_type
          @metadata[:mime_type] || Mime::Type.lookup_by_extension(s3obj.content_type || ::File.extname(filename)[1..-1])
        end

        # =Data=
        def blob
          _store[key]
        end

        # Returns a closed Tempfile of source's data.
        def tempfile
          ::Tempfile.new(filename, tempfile_path).tap do |tmp|
            tmp.write blob
            tmp.close
          end
        end

        def io
          tempfile
        end

        # =State Transitions=
        def destroy
          _store.delete(key)
          freeze
        end

        private
        def key
          uri.path.split('/')[-1]
        end
      end
    end
  end
end