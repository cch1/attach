module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for CGI File-based sources (either the StringIO or Tempfile manifestation with singleton methods for metadata)
      # Also handles the strange example of AC:TUF.
      class CGIUpload < GroupSmarts::Attach::Sources::IO
        # =State Transitions=
        # Convert the bastard IO source into a more specific source.
        def get
          case io
            when Tempfile then Sources::Tempfile.new(self).swallow(io) 
            when ActionController::TestUploadedFile then Sources::Tempfile.new(self).swallow(io.instance_variable_get(:@tempfile))
            when StringIO then Sources::IO.new(self).swallow(io)
          end
        end
        
        # Persist ourself.
        def store(id)
          self.get.store(id)
        end
        
        # Process ourself
        def process(t)
          self.get.process(t)
        end
        
        # =Metadata=
        # Returns a URI string representing the attachment.
        def uri
          ::URI.parse(@io.original_filename)
        end
        
        # Returns the MIME::Type of source.
        def mime_type
          @io.content_type
        end
        
        # Augment metadata
        def metadata
          returning super do |h|
            h[:uri] = uri
            h[:mime_type] = mime_type
          end          
        end        
      end
    end
  end
end