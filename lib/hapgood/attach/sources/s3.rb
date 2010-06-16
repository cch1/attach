require 'aws/s3'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for duplexed Amazon S3 sources/sinks.
      class S3 < Hapgood::Attach::Sources::Base
        class S3Object < AWS::S3::S3Object;end

        attr_reader :uri

        # Create a new S3 object at the given URI and store the given source in it.
        def self.store(source, uri)
          key = uri.path.split('/')[-1]
          bucket = uri.path.split('/')[1]
          raise "Target object already exists! (#{key}) " if S3Object.exists?(key, bucket)
          S3Object.store(key, source.blob, bucket)
          self.new(uri, source.metadata)
        end

        # Reload a persisted source
        def self.reload(uri, metadata = {})
          self.new(uri, metadata)
        end

        def self.config
          @@config ||= {:credentials => {:secret_access_key => nil, :access_key_id => nil}}
        end

        def self.establish_connection!
          AWS::S3::Base.establish_connection!(config[:credentials]) unless AWS::S3::Base.connected?
          S3Object.establish_connection!(config[:credentials])
        end

        def initialize(uri, m = {})
          super
          @uri = @data
        end

        def valid?
          (!!s3obj).tap do |v|
            @error = "Missing S3 object" unless v
          end
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
        # Return ::URI where this attachment is available via http
        def public_uri
          URI.parse(s3obj.url)
        end

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
          s3obj.value
        end

        # Returns a closed Tempfile of source's data.
        def tempfile
          returning ::Tempfile.new(filename, tempfile_path) do |tmp|
            tmp.write s3obj.value
            tmp.close
          end
        end

        def io
          tempfile
        end

        # =State Transitions=
        def destroy
          begin
            s3obj.delete
          rescue AWS::S3::NoSuchKey => e
            raise MissingSource, e.to_s
          ensure
            super
          end
        end

        private
        def s3obj
          @s3obj ||= begin
            key = uri.path.split('/')[-1]
            bucket = uri.path.split('/')[1]
            S3Object.find(key, bucket)
          rescue AWS::S3::NoSuchKey
            nil
          end
        end
      end
    end
  end
end