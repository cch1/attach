require File.dirname(__FILE__) + '/test_helper.rb'

class SourceHttpTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  def test_load
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
    assert_equal 13036, s.size
  end

  def test_reload
    uri = URI.parse("http://www.rubyonrails.org/images/rails.png")
    s = Hapgood::Attach::Sources::Http.reload(uri)
    assert_equal 13036, s.size
  end

  def test_destroy
    uri = URI.parse("http://www.rubyonrails.org/images/rails.png")
    s = Hapgood::Attach::Sources::Http.reload(uri)
    s.destroy
  end

  def test_public_path
    uri = URI.parse("http://www.rubyonrails.org/images/rails.png")
    s = Hapgood::Attach::Sources::Http.reload(uri)
    assert_equal uri, s.public_uri
  end

  def test_delete_with_missing_data
    uri = ::URI.parse("http://nonexistent.com/something_missing")
    s = Hapgood::Attach::Sources::Http.new(uri, {})
    assert_nothing_raised do
      s.destroy
    end
  end

  def test_invalid_with_missing_data
    uri = ::URI.parse("http://nonexistent.com/something_missing")
    s = Hapgood::Attach::Sources::Http.new(uri, {})
    assert_nothing_raised do
      assert !s.valid?
    end
  end

  def test_reload_with_missing_data
    uri = ::URI.parse("http://nonexistent.com/something_missing")
    assert_nothing_raised do
      Hapgood::Attach::Sources::Http.reload(uri)
    end
  end
end