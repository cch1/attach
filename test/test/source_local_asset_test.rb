require File.dirname(__FILE__) + '/test_helper.rb'

class SourceLocalAssetTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  def test_load
    pathname = Pathname.new(ActionView::Helpers::AssetTagHelper::ASSETS_DIR).join('images', 'logo.gif')
    s = Hapgood::Attach::Sources::LocalAsset.load(pathname)
    assert_instance_of Hapgood::Attach::Sources::LocalAsset, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    assert_kind_of ::IO, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_not_nil s.uri
    assert s.uri.relative?
    assert_equal pathname.to_s, s.uri.path
    assert_equal 'logo.gif', s.filename
    assert_equal 'image/gif', s.mime_type.to_s # File's MIME type is guessed from extension
    assert_equal "Nlmsf6jL1y031dv5yaI3Ew==", Base64.encode64(s.digest).chomp! # This resource is not served with a rich HTTP header
    assert_equal 14762, s.size
  end

  def test_load_source_from_relative_path
    p = Pathname.new(Rails.root).join('public', 'images', 'logo.gif').relative_path_from(Pathname.getwd)
    s = Hapgood::Attach::Sources::LocalAsset.load(p)
    assert s.valid?
    assert Pathname.new(s.uri.path).absolute?
  end

  def test_reload
    uri = URI.parse(File.join(ActionView::Helpers::AssetTagHelper::ASSETS_DIR, 'images', 'logo.gif'))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_kind_of Hapgood::Attach::Sources::LocalAsset, s
    assert_equal 14762, s.size
    assert_equal uri, s.uri
  end

  def test_destroy
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

  def test_public_path_available
    pathname = Pathname.new(ActionView::Helpers::AssetTagHelper::ASSETS_DIR).join('images', 'logo.gif')
    assert pathname.exist?
    s = Hapgood::Attach::Sources::LocalAsset.load(pathname)
    assert_not_nil s.public_uri
    assert Pathname.new(s.public_uri.path).absolute?
    assert Pathname.new(Rails.public_path).join(s.public_uri.to_s[1..-1]).exist?
  end

  def test_public_path_unavailable
    hidden_public = File.join(Rails.public_path, 'javascripts')
    Rails.stubs(:public_path).returns(hidden_public)
    pathname = Pathname.new(ActionView::Helpers::AssetTagHelper::ASSETS_DIR).join('images', 'logo.gif')
    s = Hapgood::Attach::Sources::LocalAsset.load(pathname)
    assert_nil s.public_uri
  end

  def test_delete_with_missing_data
    uri = ::URI.parse("file:/something_missing")
    s = Hapgood::Attach::Sources::File.new(uri, {})
    assert_nothing_raised do
      s.destroy
    end
  end

  def test_invalid_with_missing_data
    uri = ::URI.parse("file:/something_missing")
    s = Hapgood::Attach::Sources::File.new(uri, {})
    assert_nothing_raised do
      assert !s.valid?
    end
  end

  def test_reload_with_missing_data
    uri = ::URI.parse("file:/something_missing")
    assert_nothing_raised do
      Hapgood::Attach::Sources::File.reload(uri)
    end
  end
end