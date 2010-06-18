require File.dirname(__FILE__) + '/test_helper.rb'

class SourceTempfileTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  def test_load
    tf = tempfile('attachments/SperrySlantStar.bmp', true)
    s = Hapgood::Attach::Sources::Tempfile.load(tf)
    assert_instance_of Hapgood::Attach::Sources::Tempfile, s
    assert s.valid?
    # Check data
    assert_kind_of ::Tempfile, s.tempfile
    [:open, :close, :read].each {|m| assert s.io.respond_to?(m)} # quacks like an IO
    assert_kind_of ::String, s.blob
    # Check metadata
    assert s.metadata
    assert_kind_of String, s.filename
    assert_nil s.mime_type
    assert_kind_of String, s.digest
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(s.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
    assert_equal 4534, s.size
  end

  def test_store
    s0 = stubbed_source
    path = File.join(Attachment::FILE_STORE, 'uuid_aspect.extension')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    assert_raises RuntimeError do
      Hapgood::Attach::Sources::Tempfile.store(s0, uri)
    end
  end

  def test_reload
    path = File.join(Attachment::FILE_STORE, 'rails.png')
    uri = ::URI.parse("file://localhost").merge(::URI.parse(path))
    assert_raises RuntimeError do
      Hapgood::Attach::Sources::Tempfile.reload(uri)
    end
  end

  def test_destroy
    tf = tempfile('attachments/SperrySlantStar.bmp', true)
    assert File.readable?(tf.path)
    s = Hapgood::Attach::Sources::Tempfile.load(tf)
    s.destroy
    assert_nil tf.path
  end

  def test_public_path
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = Hapgood::Attach::Sources::Tempfile.load(tf)
    assert_raises RuntimeError do
      s.public_uri
    end
  end

  # Shamelessly stolen from ActionController
  def tempfile(path, binary = false)
    fixture_path = Pathname.new(ActionController::TestCase.send(:fixture_path))
    original_filename = path.sub(/^.*#{File::SEPARATOR}([^#{File::SEPARATOR}]+)$/) { $1 }
    Tempfile.new(original_filename).tap do |tempfile|
      tempfile.set_encoding(Encoding::BINARY) if tempfile.respond_to?(:set_encoding)
      tempfile.binmode if binary
      FileUtils.copy_file(fixture_path + path, tempfile.path)
    end
  end
end