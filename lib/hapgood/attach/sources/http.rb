require 'hapgood/attach/sources/base'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for http-based primary sources.  This class suffers from a code smell due to the dilema
      #   . In order to download intelligently...
      #   . We need to know if data is required
      #   . Data is required if image processing is required
      #   . Image processing is required if the source is an image content_type
      #   . To know the content_type of the source, we need to download at least the header
      #   . Downloading the content_type metadata (headers = HEAD) and then data (body = GET) in two calls is not intelligent.
      #   . Downloading the data unecessarily (with store = false or non-image content_type) is even dumber.
      #   . It is not practical to open the HTTP connection with a GET, read the header and then clean up nicely (with a close) because
      #     there is no callback when a source is no longer needed.
      # OPTIMIZE: Add a callback to allow the HTTP connection to be nicely closed thus allowing us to open it and read it incrementally.
      class Http < Hapgood::Attach::Sources::Base
        attr_reader :uri
        
        def self.load(*args)
          new(*args)
        end
        
        def self.reload(*args)
          new(*args)
        end
        
        # Download from a URI
        def self.download(uri, method = :head, count = 5)
          Net::HTTP.start(uri.host) do |http|
            case response = http.send(method, uri.path)
              when Net::HTTPSuccess then response
              when Net::HTTPRedirection
                raise ArgumentError, "URL results in too many redirections." if count.zero?
                download(::URI.parse(response['location']), method, count-1)
              else
                raise ArgumentError, "Couldn't open URL (#{response.message})" if method == :get
                download(uri, :get)
            end
          end
        end

        def initialize(uri, m = {})
          @uri = uri
          super
        end

        def valid?
          !!response(:head)
        rescue MissingSource => e
          @error = e.to_s
          false
        end

        # Does this source persist at the URI independent of this application?
        # This is a matter of interpretation of the stability of the host.
        # TODO: allow overriding this attribute
        def persistent?
          true
        end

        # Can this source be modified by this application?
        def readonly?
          true
        end

        # =Metadata=
        # Return ::URI where this attachment is available via http
        def public_uri
          @uri
        end

        # Returns a filename suitable for naming this attachment.
        def filename
          uri.path.split('/')[-1]
        end

        # Returns the size of the source in bytes.
        def size
          response.content_length
        end

        # Returns the Mime::Type of the source.
        def mime_type
          Mime::Type.lookup(response.content_type)
        end

        # Return the MD5 digest of the source
        def digest
          response['Content-MD5'] ? Base64.decode64(response['Content-MD5']) : super 
        end

        # =Data=
        # Return data from remote source as a blob string
        def blob
          response(:get).body
        end

        private
        # Returns the response from the remote server
        def response(method = :head)
          return @response if @method == method
          @method = method
          @response = self.class.download(uri, method)
        rescue => e
          raise MissingSource, e.to_s
        end
      end
    end
  end
end