require File.dirname(__FILE__) + '/test_helper.rb'

class SourceMemoryTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  fixtures(:attachments)

  def setup
    fn = Pathname(Fixtures::FILE_STORE) + 'rails.png'
    Hapgood::Attach::Sources::Memory._store = {'123abc' => File.read(fn)}
  end

  def test_store
    s0 = stubbed_source
    key = "0000-0000-0000.bmp"
    uri = ::URI.parse("memory:/#{key}")
    s1 = Hapgood::Attach::Sources::Memory.store(s0, uri)
    assert s1.valid?
    assert_equal "memory", s1.uri.scheme
    assert_equal uri, s1.uri
    assert_equal s0.mime_type, s1.mime_type
    assert_equal s0.filename, s1.filename
    assert_equal s0.size, s1.size
    assert_equal s0.digest, s1.digest
    assert_kind_of String, s1.blob
    assert_equal s0.blob, s1.blob
    [:open, :close, :read].each {|m| assert s1.io.respond_to?(m)} # quacks like an IO
    assert_kind_of ::Tempfile, s1.tempfile
    assert Hapgood::Attach::Sources::Memory._store.has_key?(key)
  end

  def test_reload
    key = '123abc'
    uri = ::URI.parse("memory:/#{key}")
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert s.valid?
    assert_equal 1787, s.size
  end

  def test_delete
    key = '123abc'
    uri = ::URI.parse("memory:/#{key}")
    Hapgood::Attach::Sources::Base.reload(uri).destroy
    assert !Hapgood::Attach::Sources::Memory._store.has_key?(key)
  end

  def test_delete_with_missing_data
    uri = ::URI.parse("memory:/something_missing")
    s = Hapgood::Attach::Sources::Memory.new(uri, {})
    assert_nothing_raised do
      s.destroy
    end
  end

  def test_invalid_with_missing_data
    uri = ::URI.parse("memory:/something_missing")
    s = Hapgood::Attach::Sources::Memory.new(uri, {})
    assert_nothing_raised do
      assert !s.valid?
    end
  end

  def test_reload_with_missing_data
    uri = ::URI.parse("memory:/something_missing")
    assert_nothing_raised do
      Hapgood::Attach::Sources::Memory.reload(uri)
    end
  end
end