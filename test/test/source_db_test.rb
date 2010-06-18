require File.dirname(__FILE__) + '/test_helper.rb'

class SourceDbTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  include ActionView::Helpers::AssetTagHelper

  fixtures :attachments, :attachment_blobs

  def test_store_source_to_db
    s0 = stubbed_source
    uri = ::URI.parse("db://localhost/")
    s1 = Hapgood::Attach::Sources::ActiveRecord.store(s0, uri)
    assert dbf = Hapgood::Attach::AttachmentBlob.find(s1.uri.path.split('/')[-1])
    assert_equal s0.size, dbf.blob.size
  end

  def test_reload_source_from_db_uri
    id = Fixtures.identify('one')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_destroy_db_backed_source
    id = Fixtures.identify('one')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert !Hapgood::Attach::AttachmentBlob.exists?(id)
  end

  def test_public_path
    id = Fixtures.identify('one')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_nil s.public_uri
  end

  def test_delete_with_missing_data
    uri = ::URI.parse("db:/localhost/0")
    s = Hapgood::Attach::Sources::ActiveRecord.new(uri, {})
    assert_nothing_raised do
      s.destroy
    end
  end

  def test_invalid_with_missing_data
    uri = ::URI.parse("db:/localhost/0")
    s = Hapgood::Attach::Sources::ActiveRecord.new(uri, {})
    assert_nothing_raised do
      assert !s.valid?
    end
  end

  def test_reload_with_missing_data
    uri = ::URI.parse("db:/localhost/0")
    assert_nothing_raised do
      Hapgood::Attach::Sources::ActiveRecord.reload(uri)
    end
  end
end