require 'hapgood/attach/sources/file'

module Hapgood # :nodoc:
  module Attach # :nodoc:
    module Sources
      class LocalAsset < Hapgood::Attach::Sources::File
        def self.load(pathname, metadata = {})
          path = URI.encode(pathname.realpath.to_s)
          uri = URI.parse(path)
          self.new(uri, metadata)
        end

        # Does this source persist at the URI independent of this application?
        def persistent?
          true
        end

        # Can this source be modified by this application?
        def readonly?
          true
        end

        # =Metadata=
        # Return ::URI where this attachment is available via http
        def public_uri
          pp = pathname.realpath.relative_path_from(Pathname.new(Rails.public_path).realpath)
          pp.to_s.match(/\.\./) ? nil : URI.parse("/" + pp)
        end

        # =State Transitions=
        def destroy
          # Do nothing -a local asset should outlive any referencing source and its associated attachment.
        end
      end
    end
  end
end