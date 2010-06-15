require File.dirname(__FILE__) + '/test_helper.rb'

class SourceTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  include ActionView::Helpers::AssetTagHelper

  def test_load_source_from_tempfile
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = Hapgood::Attach::Sources::Base.load(tf)
    assert_instance_of Hapgood::Attach::Sources::Tempfile, s
    assert s.valid?
    # Check data
    assert_kind_of ::ActionController::TestUploadedFile, s.tempfile
    assert_kind_of ::ActionController::TestUploadedFile, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_nil s.uri  # Tempfiles are not persistent
    assert_kind_of String, s.filename
    assert_kind_of Mime::Type, s.mime_type
    assert_kind_of String, s.digest
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(s.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
    assert_equal 4534, s.size
  end

  def test_load_source_from_http
    uri = URI.parse("http://www.rubyonrails.org/images/rails.png")
    s = Hapgood::Attach::Sources::Base.load(uri)
    assert_instance_of Hapgood::Attach::Sources::Http, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    assert_kind_of ::StringIO, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_not_nil s.uri
    assert_equal uri, s.uri
    assert_equal 'rails.png', s.filename
    assert_equal "image/png", s.mime_type.to_s
    assert_nil s.digest # This resource is not served with a rich HTTP header
    assert_equal 13036, s.size
  end

  def test_load_source_from_local_asset
    uri = URI.parse(image_path('logo.gif'))
    s = Hapgood::Attach::Sources::Base.load(uri)
    assert_instance_of Hapgood::Attach::Sources::LocalAsset, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    assert_kind_of ::File, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_not_nil s.uri
    assert_equal uri, s.uri
    assert_equal 'logo.gif', s.filename
    assert_equal 'image/gif', s.mime_type.to_s # File's MIME type is guessed from extension
    assert_equal "Nlmsf6jL1y031dv5yaI3Ew==", Base64.encode64(s.digest).chomp! # This resource is not served with a rich HTTP header
    assert_equal 14762, s.size
  end

  def test_reload_source_from_local_asset_uri
    uri = URI.parse(image_path('logo.gif'))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_kind_of Hapgood::Attach::Sources::LocalAsset, s
    assert_equal 14762, s.size
    assert_equal uri, s.uri
  end

  def test_destroy_local_asset_source
    sdir = Pathname(Fixtures::FILE_STORE)
    ddir = Pathname(File.join(RAILS_ROOT, 'public', 'test_assets'))
    path = ddir + 'rails.png'
    FileUtils.mkdir ddir
    FileUtils.cp sdir + 'rails.png', ddir
    uri = URI.parse(File.join('test_assets', 'rails.png'))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert File.readable?(path)
  ensure
    FileUtils.rm_rf ddir
  end

  def test_process_thumbnail_with_rmagick
    s = Hapgood::Attach::Sources::Base.load(fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
    assert s = Hapgood::Attach::Sources::Base.process(s, :thumbnail)
    assert_equal 128, s.metadata[:width]
    assert_equal 102, s.metadata[:height]
    assert_operator 4616..4636, :include?, s.size
    assert_operator 4616..4636, :include?, s.blob.size
  end

  def test_process_info_with_exifr
    s = Hapgood::Attach::Sources::Base.load(fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
    assert s = Hapgood::Attach::Sources::Base.process(s, :info)
    assert s.metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 -0500'), s.metadata[:time].to_time
  end

  def test_process_with_icon
    s = Hapgood::Attach::Sources::Base.load(fixture_file_upload('attachments/empty.txt', 'text/plain', :binary))
    assert s = Hapgood::Attach::Sources::Base.process(s, :icon)
    assert_kind_of Hapgood::Attach::Sources::LocalAsset, s
    assert_equal 'image/png', s.mime_type.to_s
    assert_match /(\/.*)+\/mime_type_icons.text_plain\.png/, s.uri.path
  end
end