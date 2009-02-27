module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for IO-based sources.
      class IO < GroupSmarts::Attach::Sources::Base
        # =Metadata=
        # Returns a file name suitable for this source when saved in a persistent file.
        def filename
          @data.respond_to?(:original_filename) ? @data.original_filename : super
        end
        
        # Returns the MIME::Type of source.
        def mime_type
          @mime_type ||= @data.respond_to?(:content_type) ? ::Mime::Type.lookup(@tempfile.content_type) : super
        end
        
        # =Data=
        # Returns the rewound IO instance that we are proxying.
        def io
          @data.rewind
          @data
        end
        
        # Returns the source's data as a blob string.  WARNING: Performance problems can result if the source is large
        def blob
          io.read
        end
      end
    end
  end
end