require 'tempfile'

Tempfile.class_eval do
  # overwrite so tempfiles use the extension of the basename.  important for rmagick and image science
  def make_tmpname(basename, n)
    ext = nil
    sprintf("%s%d-%d%s", basename.to_s.gsub(/\.\w+$/) { |s| ext = s; '' }, $$, n, ext)
  end
end

require 'geometry'
ActiveRecord::Base.send(:extend, Hapgood::Attach::ActMethods)
Hapgood::Attach.tempfile_path = ATTACH_TEMPFILE_PATH if Object.const_defined?(:ATTACH_TEMPFILE_PATH)
FileUtils.mkdir_p Hapgood::Attach.tempfile_path