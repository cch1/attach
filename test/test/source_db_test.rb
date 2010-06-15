require File.dirname(__FILE__) + '/test_helper.rb'

class SourceDbTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  include ActionView::Helpers::AssetTagHelper

  fixtures :attachments, :attachment_blobs

  def test_store_source_to_db
    tf = fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)
    s = Hapgood::Attach::Sources::Base.load(tf)
    uri = ::URI.parse("db://localhost/")
    s = Hapgood::Attach::Sources::Base.store(s, uri)
    assert dbf = Hapgood::Attach::AttachmentBlob.find(s.uri.path.split('/')[-1])
    assert_equal 4534, dbf.blob.size
  end

  def test_reload_source_from_db_uri
    id = Fixtures.identify('one')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    assert_equal 1787, s.size
  end

  def test_reload_source_from_invalid_db_uri
    id = Fixtures.identify('xone')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    assert_raises ActiveRecord::RecordNotFound do
      s = Hapgood::Attach::Sources::Base.reload(uri)
    end
  end

  def test_destroy_db_backed_source
    id = Fixtures.identify('one')
    uri = ::URI.parse("db://localhost").merge(::URI.parse(id.to_s))
    s = Hapgood::Attach::Sources::Base.reload(uri)
    s.destroy
    assert !Hapgood::Attach::AttachmentBlob.exists?(id)
  end
end