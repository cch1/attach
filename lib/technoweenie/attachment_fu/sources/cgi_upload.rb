module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Sources
      # Methods for CGI File-based sources (either the StringIO or Tempfile manifestation with singleton methods for metadata)
      class CGIUpload < Technoweenie::AttachmentFu::Sources::IO
        # Return size of source in bytes.
        def size
          @source.size
        end
        
        # Return content type of source as a string.
        def content_type
          @source.content_type
        end
        
        # Return a filename for the source
        def filename
          @source.original_filename
        end
        
        # Return the MD5 digest of the source
        def digest
          Digest::MD5.digest(data)
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