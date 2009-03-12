module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for Tempfile-based primary sources.
      class Tempfile < GroupSmarts::Attach::Sources::File
        def initialize(tempfile, metadata)
          super
          @tempfile = @data
        end
        
        # =Metadata=
        # Returns the URI of the source.
        def uri
          nil
        end
        
        # Returns the MIME::Type of source.
        def mime_type
          @mime_type ||= Mime::Type.lookup_by_extension(filename.split('.')[-1])
          super || @mime_type
        end
        
        # =Data=
        # Returns the source's data as a blob string.  WARNING: Performance problems can result if the source is large
        def blob
          tempfile.read
        end

        # Trivial short-circuit that returns the rewind tempfile itself.
        def tempfile
          @tempfile.rewind
          @tempfile
        end

        # Returns the rewound IO instance that we are proxying.
        def io
          tempfile
        end
      end
    end
  end
end