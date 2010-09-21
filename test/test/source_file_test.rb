require File.dirname(__FILE__) + '/test_helper.rb'

class SourceFileTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  def setup
    FileUtils.mkdir Attachment::FILE_STORE
    FileUtils.cp_r File.join(Fixtures::FILE_STORE, '.'), Attachment::FILE_STORE
  end

  def teardown
    FileUtils.rm_rf Attachment::FILE_STORE
  end

  def test_load
    f = ::File.open(File.join(Attachment::FILE_STORE, 'SperrySlantStar.bmp'), "rb")
    s = Hapgood::Attach::Sources::File.load(f)
    assert_instance_of Hapgood::Attach::Sources::File, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    assert_kind_of ::IO, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_not_nil s.uri
    assert_equal "file://localhost#{f.path}", s.uri.to_s
    assert_equal 'SperrySlantStar.bmp', s.filename
    assert_equal 'image/bmp', s.mime_type.to_s # File's MIME type is guessed from extension
    assert_not_nil s.digest
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(s.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
    assert_equal 4534, s.size
  end

  def test_store
    s0 = stubbed_source
    path = File.join(Attachment::FILE_STORE, 'uuid_aspect.extension')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    Hapgood::Attach::Sources::Base.store(s0, uri)
    assert stat = File.stat(path)
    assert_equal 0644, stat.mode & 0777
    assert_equal s0.size, File.size(path)
  end

  def test_reload
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_destroy
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert !File.readable?(path)
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