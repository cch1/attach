module GroupSmarts # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for sources that start with an existing source but override some of its aspects.
      class Wrapper < GroupSmarts::Attach::Sources::Base
        attr_writer :size, :filename, :content_type, :digest

        # Squirrel away the target
        def initialize(target)
          super
          @target = target
        end
        
        def filename
          @filename || @target.filename
        end

        # The proxy target is the wrapped source.  Send any unresolved calls to it.
        def method_missing(method, *args, &block)
          @target.__send__(method, *args, &block)
        end
        
        # Affirm we respond to proxy target's methods.
        def respond_to?(method_id, include_private = false)
          return true if @target.respond_to?(method_id, include_private)
          super
        end
      end
    end
  end
end