require File.dirname(__FILE__) + '/test_helper.rb'

class ModelTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  fixtures :attachments, :attachment_blobs, :users

  def setup
    FileUtils.mkdir Attachment::FILE_STORE
    FileUtils.cp_r File.join(Fixtures::FILE_STORE, '.'), Attachment::FILE_STORE

    test_key = "a03340f7-ba9e-4e19-854f-c8fa8e651574.png"
    raise "Suspicious bucket name for tests!" unless Attachment::S3_BUCKET.match(/test/)
    raise "Suspicious FILE_STORE for tests!" unless Attachment::FILE_STORE.match(/test/)
    fn = Pathname(Fixtures::FILE_STORE) + 'rails.png'
    AWS::S3::S3Object.store(test_key, File.open(fn, 'rb'), Attachment::S3_BUCKET)
    Hapgood::Attach::Sources::Memory._store = {test_key => File.read(fn)}
    @ao = Attachment.attachment_options.dup
  end

  def teardown
    Attachment.attachment_options = @ao
    AWS::S3::Bucket.find(Attachment::S3_BUCKET).delete_all
    FileUtils.rm_rf Attachment::FILE_STORE
  end

  def test_create_attachment_via_file
    assert_difference 'Attachment.count' do
      a = Attachment.create(:file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary))
      assert a.valid?, a.errors.full_messages.first
      assert_equal 'SperrySlantStar.bmp', a.filename
      assert_not_nil a.digest
      assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
      assert_equal 4534, a.size
      assert a.source.persistent?
    end
  end

  def test_create_with_empty_file
    assert_difference 'Attachment.count' do
      a = Attachment.create(:file => fixture_file_upload('attachments/empty.txt', 'text/plain'))
      assert a.valid?, a.errors.full_messages.first  # Attachment.attachment_options
      assert_equal 'empty.txt', a.filename
      assert_not_nil a.digest
      assert_equal "1B2M2Y8AsgTpgAmY7PhCfg==", Base64.encode64(a.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
      assert_equal 0, a.size
      assert a.source.persistent?
    end
  end

  # Do attachments holding rehydrated sources behave?
  def test_source_rehydration
    a = attachments(:one)
    assert_not_nil a.source
    assert_equal 630, a.blob.size
  end

  def test_create_attachment_via_url
    url = "http://cho.hapgoods.com/wordpress"
    assert_difference 'Attachment.count' do
      a = Attachment.create(:url => url)
      assert a.valid?, a.errors.full_messages.first
      assert_equal url, a.url
    end
  end

  def test_double_save_new_attachment
    assert_difference 'Attachment.count', 1 do
      a = Attachment.create(:file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary))
      assert !a.instance_variable_get(:@source_updated)
      a.save
    end
  end

  def test_store_only_when_requested
    assert_difference "Hapgood::Attach::Sources::Memory._store.keys.size", 0 do
      url = 'http://www.memoryminer.com/graphics/missingphoto.jpg'
      Attachment.create(:url => url, :store => false)
    end
  end

  def test_store_when_requested
    assert_difference "Hapgood::Attach::Sources::Memory._store.keys.size", 1 do
      url = 'http://www.memoryminer.com/graphics/missingphoto.jpg'
      Attachment.create(:url => url, :store => true)
    end
  end

  # Classic problems here include caching sources in a limited high-performance mode during validation only to find that all data is required later.
  # Also state variables in the attach instance methods are tricky to keep in sync during assignment.
  def test_validation_independence
    assert_nothing_raised do
      a = Attachment.new(:file => fixture_file_upload('/attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
      assert a.valid?
      a.save!
    end
  end

  def test_create_attachment_with_malformed_url
    assert_nothing_raised do
      u = "http://"
      a = Attachment.create(:url => u)
      assert !a.valid?
      assert_equal u, a.url
      assert a.errors[:url]
    end
  end

  # The #url virtual attribute should behave like a normal attribute.
  def test_create_attachment_with_invalid_url
    assert_nothing_raised do
      u = "http://ffew.aa.xyz/dd.nfg"
      a = Attachment.create(:url => u)
      assert !a.valid?
      assert_equal u, a.url
      assert a.errors[:url]
    end
  end

  def test_validation_with_missing_source_store
    assert_nothing_raised do
      a = attachments(:missing)
      assert !a.valid?
      assert a.errors[:source]
    end
  end

  def test_source_required_on_save
    assert_no_difference 'Attachment.count' do
      a = Attachment.new({})
      a.save
      assert a.errors.any?
    end
  end

  def test_delete_simple
    assert_difference 'Attachment.count', -1 do
      assert_difference 'Hapgood::Attach::AttachmentBlob.count', -1 do #DbFile.count
        res = attachments(:db_sss).destroy
      end
    end
  end

  def test_update_simple
    a = Attachment.find(attachments(:two).id)
    a.description = "Updated Description"
    assert_nothing_raised do
      a.save!
    end
    assert_equal "Updated Description", Attachment.find(attachments(:two).id).description
  end

  def test_create_simple
    assert_no_difference 'Attachment.count' do
      assert_nothing_raised do
        a = Attachment.create
      end
    end
  end

  def test_info
    assert attachments(:two).metadata[:time]
    assert attachments(:two).metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 16 Nov 1998 11:39:37 +0000'), attachments(:two).metadata[:time]
  end

  def test_info_on_new
    a = Attachment.create(:file => fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
    assert a.metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 -0500'), a.metadata[:time].to_time
  end

  def test_update
    url = "http://www.rubyonrails.org/images/rails.png"
    attachments(:sss).update_attributes({:url => url})
    assert_equal url, attachments(:sss).url
  end

  def test_generate_storage_uri_with_bogus_mime_type
    a = Attachment.create(:file => fixture_file_upload('attachments/ManagingAgileProjects.pdf', 'example/example', :binary))
    p = Pathname.new(a.uri.path)
    assert_no_match /example\/example/, p.to_s  # make sure bogus Mime::Type does not appear literally in path.
  end

  def test_storage_uri_has_reasonable_file_extension
    mt = Mime::Type.lookup_by_extension('pdf')
    a = Attachment.create(:file => fixture_file_upload('attachments/ManagingAgileProjects.pdf', mt.to_s, :binary))
    p = Pathname.new(a.uri.path)
    assert_equal mt.to_sym.to_s, p.extname[1..-1]
  end

  def test_source_metadata_is_assigned_to_attributes
    a = Attachment.new(:file => fixture_file_upload('attachments/ManagingAgileProjects.pdf', 'application/pdf', :binary))
    assert_equal 144866, a.size
    assert_equal 'application/pdf', a.content_type
    assert_equal "ManagingAgileProjects.pdf", a.filename
  end

  def test_destroy_with_missing_source
    assert_nothing_raised do
      attachments(:missing).destroy
    end
  end
end