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

  def test_load_source_from_file
    f = ::File.open(File.join(Attachment::FILE_STORE, 'SperrySlantStar.bmp'), "rb")
    s = Hapgood::Attach::Sources::Base.load(f)
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

  def test_store_source_to_file
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = Hapgood::Attach::Sources::Base.load(tf)
    path = File.join(Attachment::FILE_STORE, 'uuid_aspect.extension')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.store(s, uri)
    assert stat = File.stat(path)
    assert_equal 0644, stat.mode & 0777
    assert_equal 4534, File.size(path)
  end

  def test_store_source_to_file_with_relative_path
    begin
      tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
      s = Hapgood::Attach::Sources::Base.load(tf)
      path = File.join(File.join('test', 'public', 'attachments'), 'uuid_aspect.extension')
      uri = ::URI.parse(path)
      s = Hapgood::Attach::Sources::Base.store(s, uri)
      assert stat = File.stat(path)
      assert_equal 0644, stat.mode & 0777
      assert_equal 4534, File.size(path)
    ensure
      FileUtils.rm path
    end
  end

  def test_reload_source_from_file_uri
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_reload_source_from_relative_uri
    path = File.join('..', 'public', 'attach_test', 'rails.png')
    uri = ::URI.parse(path)
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_reload_source_from_invalid_file_uri
    path = File.join(Attachment::FILE_STORE, 'xrails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    assert_raises Hapgood::Attach::MissingSource do
      s = Hapgood::Attach::Sources::Base.reload(uri)
    end
  end

  def test_destroy_file_backed_source
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert !File.readable?(path)
  end

  uses_mocha "mock Rails.public_path" do
    def test_public_path_available
      Rails.stubs(:public_path).returns(File.join(Attachment::FILE_STORE, '..'))
      path = File.join(Attachment::FILE_STORE, 'rails.png')
      uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
      s = Hapgood::Attach::Sources::Base.reload(uri)
      assert_not_nil s.public_uri
      assert Pathname.new(Rails.public_path).join(s.public_uri.to_s).exist?
    end

    def test_public_path_unavailable
      Rails.stubs(:public_path).returns(File.join(Attachment::FILE_STORE, '..', 'sibling'))
      path = File.join(Attachment::FILE_STORE, 'rails.png')
      uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
      s = Hapgood::Attach::Sources::Base.reload(uri)
      assert_nil s.public_uri
    end
  end
end