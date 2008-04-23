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
      
        def initialize(url, d = false)
          super
          @source = url
          @download = d
        end

        # Returns the data of this source as an IO-compatible object
        def io
          @io ||= StringIO.new(response.body || "", 'rb')
        end

        def uri
          @uri ||= ::URI.parse(@source)
        end
        
        # Returns the response from the remote server
        def response
          @response ||= self.class.download(uri, @download ? :get : :head)
        end
        
        # Return size of source in bytes.
        def size
          response.content_length || response.body.size
        end
        
        # Return content type of source as a string.
        def content_type
          response.content_type
        end
        
        # Return a filename for the source
        def filename
          uri.path.split('/')[-1] || 'downloaded_attachment'
        end
        
        # Return the MD5 digest of the source
        def digest
          if response['Content-MD5']
            ActiveSupport::Base64.decode64(response['Content-MD5'])
          elsif data
            Digest::MD5.digest(data)
          end
        end
        
        # Return the source's data.  WARNING: Performance problems can result if the source is large, remote or both.
        def data
          response.body
        end

        # Return the source's data as a tempfile.  WARNING: Performance problems can result if the source is large, remote or both.
        # TODO: Return a true tempfile.
        def tempfile
          returning Tempfile.new(filename, GroupSmarts::Attach.tempfile_path) do |tmp|
            tmp.binmode
            tmp.write(data)
            tmp.close
          end
        end
      end
    end
  end
end