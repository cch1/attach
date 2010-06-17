require File.dirname(__FILE__) + '/test_helper.rb'
require 'net/http'

class SourceS3Test < ActiveSupport::TestCase
  include ActionController::TestProcess

  fixtures(:attachments)

  def setup
    @test_bucket = 'attach_test'
    @test_key = "a03340f7-ba9e-4e19-854f-c8fa8e651574.png"
    raise "Suspicious bucket name for tests!" unless @test_bucket.match(/test/)
    fn = Pathname(Fixtures::FILE_STORE) + 'rails.png'
    AWS::S3::S3Object.store(@test_key, File.open(fn, 'rb'), @test_bucket)
  end

  def teardown
    AWS::S3::Bucket.find(@test_bucket).delete_all
  end

  def test_new
    uri = ::URI.parse("s3:/#{@test_bucket}/#{@test_key}")
    s = Hapgood::Attach::Sources::S3.new(uri)
    assert s.valid?
    assert_equal 1787, s.size
  end

  def test_store
    s0 = stubbed_source
    key = "0000-0000-0000.bmp"
    uri = ::URI.parse("s3:/#{@test_bucket}/#{key}")
    s1 = Hapgood::Attach::Sources::S3.store(s0, uri)
    assert s1.valid?
    assert_equal "s3", s1.uri.scheme
    assert_equal uri, s1.uri # If a canonical representation including the host and bucket is supported, this may no longer be a valid test
    assert_equal s0.mime_type, s1.mime_type
    assert_equal s0.filename, s1.filename
    assert_equal s0.size, s1.size
    assert_equal s0.digest, s1.digest
    assert_kind_of String, s1.blob
    assert_equal s0.blob, s1.blob
    [:open, :close, :read].each {|m| assert s1.io.respond_to?(m)} # quacks like an IO
    assert_kind_of ::Tempfile, s1.tempfile
    assert AWS::S3::S3Object.find(key, @test_bucket)
  end

  def test_reload
    uri = ::URI.parse("s3:/#{@test_bucket}/#{@test_key}")
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert s.valid?
    assert_equal 1787, s.size
  end

  def test_delete
    uri = ::URI.parse("s3:/#{@test_bucket}/#{@test_key}")
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert_nil @test_bucket["a03340f7-ba9e-4e19-854f-c8fa8e651574.png"]
    assert s.frozen?
  end

  def test_delete_with_missing_data
    uri = ::URI.parse("s3:/#{@test_bucket}/something_missing")
    s = Hapgood::Attach::Sources::S3.new(uri, {})
    assert_nothing_raised do
      s.destroy
    end
  end

  def test_invalid_with_missing_data
    uri = ::URI.parse("s3:/#{@test_bucket}/something_missing")
    s = Hapgood::Attach::Sources::S3.new(uri, {})
    assert_nothing_raised do
      assert !s.valid?
    end
  end

  def test_reload_with_missing_data
    uri = ::URI.parse("s3:/#{@test_bucket}/something_missing")
    assert_nothing_raised do
      Hapgood::Attach::Sources::S3.reload(uri)
    end
  end

  # The semantics for fetching S3 data the first time support streaming -but not subsequent (cached) fetches.  Don't get burned.
  def test_fetch_cached_data
    uri = ::URI.parse("s3:/#{@test_bucket}/#{@test_key}")
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert !File.size(s.tempfile.path).zero?
  end

  def test_public_path
    uri = ::URI.parse("s3:/#{@test_bucket}/#{@test_key}")
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_not_nil uri = s.public_uri
    Net::HTTP.new(uri.host, uri.port).start {|http|
      # A HEAD request would be smarter, but apparently the expected HTTP method (GET) is included in the signature parameter.
      response = http.request_get(uri.request_uri)
      assert_kind_of Net::HTTPSuccess, response
    }
  end
end