require 'hapgood/attach/sources/io'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      # Methods for Tempfile-based primary sources.
      class Tempfile < Hapgood::Attach::Sources::IO
        def self.load(tempfile, metadata = {})
          self.new(tempfile, metadata)
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          false
        end

        # Can this source be modified by this application?
        def readonly?
          false
        end

        # =Metadata=
        def public_uri
          raise "Tempfile not available to public"
        end

        # =Data=
        def pathname
          @pathname ||= Pathname.new(@data.path)
        end

        # =State Transitions=
        def destroy
          @data.delete
          @data = nil
        rescue Errno::ENOENT
        ensure
          freeze
        end
      end
    end
  end
end