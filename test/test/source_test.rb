require File.dirname(__FILE__) + '/test_helper.rb'

class SourceTest < ActiveSupport::TestCase
  UUID_RE = /[[:xdigit:]]{8}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{4}[:-][[:xdigit:]]{12}/

  fixtures :users, :attachments, :attachment_blobs

  FILE_STORE = File.join(RAILS_ROOT, 'public', 'attachments')
  FIXTURE_FILE_STORE = File.join(RAILS_ROOT, 'test', 'fixtures', 'attachments')

  def setup
    FileUtils.mkdir FILE_STORE
    FileUtils.cp_r File.join(FIXTURE_FILE_STORE, '.'), FILE_STORE
  end

  def teardown
    FileUtils.rm_rf FILE_STORE
  end

  def test_load_source_from_augmented_tempfile
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = GroupSmarts::Attach::Sources::Base.load(tf)
    assert_instance_of GroupSmarts::Attach::Sources::Tempfile, s
    assert s.valid?
    # Check data
    assert_kind_of ::ActionController::TestUploadedFile, s.tempfile
    assert_kind_of ::ActionController::TestUploadedFile, s.io
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_nil s.uri  # Tempfiles are not persistent
    assert_equal 'SperrySlantStar.bmp', s.filename
    assert_not_nil s.mime_type
    assert_not_nil s.digest
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(s.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
    assert_equal 4534, s.size
  end

  def test_load_source_from_file
    f = ::File.open(File.join(FILE_STORE, 'SperrySlantStar.bmp'), "r+b")
    s = GroupSmarts::Attach::Sources::Base.load(f)
    assert_instance_of GroupSmarts::Attach::Sources::File, s
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
    assert_nil s.mime_type # File's MIME type is indeterminate
    assert_not_nil s.digest
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(s.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
    assert_equal 4534, s.size
  end

  def test_load_source_from_http
    uri = URI.parse("http://www.rubyonrails.org/images/rails.png")
    s = GroupSmarts::Attach::Sources::Base.load(uri)
    assert_instance_of GroupSmarts::Attach::Sources::Http, s
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
    assert_equal 16531, s.size
  end

  def test_store_source_to_file
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = GroupSmarts::Attach::Sources::Base.load(tf)
    path = File.join(FILE_STORE, 'uuid_aspect.extension')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = GroupSmarts::Attach::Sources::Base.store(s, uri)
    assert File.readable?(path)
    assert_equal 4534, File.size(path)
  end

  def test_store_source_to_db
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = GroupSmarts::Attach::Sources::Base.load(tf)
    uri = ::URI.parse("db://localhost").merge(::URI.parse('12345'))
    s = GroupSmarts::Attach::Sources::Base.store(s, uri)
    assert dbf = GroupSmarts::Attach::AttachmentBlob.find(:first, :conditions => {:attachment_id => 12345})
    assert_equal 4534, dbf.blob.size
  end

  def test_reload_source_from_db_uri
    id = Fixtures.identify('one')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    s = GroupSmarts::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_reload_source_from_invalid_db_uri
    id = Fixtures.identify('xone')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    assert_raises RuntimeError do
      s = GroupSmarts::Attach::Sources::Base.reload(uri)
    end
  end

  def test_reload_source_from_file_uri
    path = File.join(FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = GroupSmarts::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_reload_source_from_invalid_file_uri
    path = File.join(FILE_STORE, 'xrails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    assert_raises GroupSmarts::Attach::MissingSource do
      s = GroupSmarts::Attach::Sources::Base.reload(uri)
    end
  end

  def test_destroy_db_backed_source
    id = Fixtures.identify('one')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    s = GroupSmarts::Attach::Sources::Base.reload(uri)
    s.destroy
    assert_nil GroupSmarts::Attach::AttachmentBlob.find(:first, :conditions => {:attachment_id => 12345})
  end

  def test_destroy_file_backed_source
    path = File.join(FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    s = GroupSmarts::Attach::Sources::Base.reload(uri)
    s.destroy
    assert !File.readable?(path)
  end
  
  def test_process_thumbnail_with_rmagick
    s = GroupSmarts::Attach::Sources::Base.load(fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
    assert s = GroupSmarts::Attach::Sources::Base.process(s, :thumbnail)
    assert_equal 128, s.metadata[:width]
    assert_equal 102, s.metadata[:height]
    assert_operator 4616..4636, :include?, s.size
    assert_operator 4616..4636, :include?, s.blob.size
  end

  def test_process_info_with_exifr
    s = GroupSmarts::Attach::Sources::Base.load(fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
    assert s = GroupSmarts::Attach::Sources::Base.process(s, :info)
    assert s.metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 -0500'), s.metadata[:time].to_time
  end
end