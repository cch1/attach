module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Sources
      # Abstract class for attachment sources.  All subclasses should provide a means of resolving
      #   size            : The size of the attachment in bytes
      #   filename        : A suitable filename for the attachment
      #   digest          : The MD5 digest of the attachment data
      #   content_type    : The MIME type of the attachment, as a string.
      #   io              : An IO-compatible object of the attachment's data
      #   data            : A blob (string) of the attachment's data
      #   tempfile        : A tempfile of the attachment
      # Any other method invocations should behave as though this object were itself an IO-compatible obeject.
      class Base
        def initialize(*args)
        end
        
        # Return an IO-compatible object of the attachment's data.  This is also our proxy target.
        def io
          raise "Abstract Class"
        end
        
        # The proxy target is the IO-like object.  Send any unresolved calls to it.
        def method_missing(method, *args, &block)
          io.__send__(method, *args, &block)
        end
        
        # Affirm we respond to proxy target's methods.
        def respond_to?(method_id, include_private = false)
          return true if io.respond_to?(method_id, include_private)
          super
        end
      end
    end
  end
end