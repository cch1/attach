module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for CGI File-based sources (either the StringIO or Tempfile manifestation with singleton methods for metadata)
      class CGIUpload < GroupSmarts::Attach::Sources::IO
        
        # Returns a URI string representing the attachment.
        def uri
          ::URI.parse(@source.original_filename)
        end
        
        # Return content type of source as a string.
        def content_type
          @source.content_type
        end
        
        # Augment metadata
        def metadata
          returning super do |h|
            h[:uri] = uri
            h[:content_type] = content_type
          end          
        end
        
        # Return the source's data.  WARNING: Performance problems can result if the source is large, remote or both.
        def data
          @data ||= @source.is_a?(StringIO) ? (@source.rewind;@source.read) : tempfile_to_data
        end

        # Return the source's data as a tempfile.  WARNING: Performance problems can result if the source is large, remote or both.
        # TODO: Convert AC:TUF to a true Tempfile.
        def tempfile
          @tempfile ||= (@source.is_a?(Tempfile)  || @source.is_a?(ActionController::TestUploadedFile))? @source : super
        end
        
        private
        def tempfile_to_data
          tempfile.read
        end
      end
    end
  end
end