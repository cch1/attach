# Due to the sequence of dependency processing and plugin initialization, these statements cannot be used to auto-install
# missing gems -they are here solely for documentation.
config.gem 'exifr', :version => '>=1.0.3'
config.gem 'rmagick', :version => '>=2.7.2', :lib => 'RMagick'
config.gem 'aws-s3', :version => '>=0.6.2', :lib => 'aws/s3'

require 'tempfile'
require 'geometry'
require 'hapgood/attach'

Tempfile.class_eval do
  # overwrite so tempfiles use the extension of the basename.  important for rmagick and image science
  def make_tmpname(basename, n)
    ext = nil
    sprintf("%s%d-%d%s", basename.to_s.gsub(/\.\w+$/) { |s| ext = s; '' }, $$, n, ext)
  end
end

Hapgood::Attach::StandardImageGeometry = { :thumbnail => ::Geometry.from_s("128x128>"),
                                  :vignette => ::Geometry.from_s('256x256>'),
                                  :proof => ::Geometry.from_s('512x512>'),
                                  :max => ::Geometry.from_s('2097152@')} # 2 Megapixels

ActiveRecord::Base.send(:extend, Hapgood::Attach::ActMethods)
FileUtils.mkdir_p Hapgood::Attach::Sources::Base.tempfile_path