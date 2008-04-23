module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for URL-based sources
      class URI < GroupSmarts::Attach::Sources::Base
        # Download from a URI
        def self.download(uri, method = :head, count = 5)
          Net::HTTP.start(uri.host) do |http|
            response = http.send(method, uri.path)
            case response
              when Net::HTTPSuccess
                return response
              when Net::HTTPRedirection
                raise ArgumentError, "URL results in too many redirections." if count.zero?
                return download(::URI.parse(response['location']), method, count-1)
              else
                raise ArgumentError, "Couldn't open URL (#{response.message})"
              end
          end
        end
      
        def initialize(url)
          super
          @source = url
        end

        def uri
          @uri ||= ::URI.parse(@source).normalize
        end
        
        # Returns the response from the remote server
        def response(full = false)
          @response ||= self.class.download(uri, full ? :get : :head)
        end
        
        def load!(full = false)
          begin
            response(full)
          rescue => e
            @error = e.message
            false
          end
        end
        
        # Return size of source in bytes.
        def size
          response.content_length || (response.body && response.body.size)
        end
        
        # Return content type of source as a string.
        def content_type
          response.content_type
        end
        
        # Return the MD5 digest of the source
        def digest
          if response['Content-MD5']
            ActiveSupport::Base64.decode64(response['Content-MD5'])
          elsif data
            super
          end
        end
        
        # Augment metadata hash
        def metadata
          returning super do |h|
            h[:uri] = uri
            h[:content_type] = content_type
          end
        end
        
        # Returns the data of this source as an IO-compatible object
        def io
          @io ||= StringIO.new(response.body || "", 'rb')
        end

        # Return the source's data.  WARNING: Performance problems can result if the source is large, remote or both.
        def data
          response.body
        end

        private
        def filename
          uri.path.split('/')[-1]
        end
      end
    end
  end
end