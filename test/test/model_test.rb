require File.dirname(__FILE__) + '/test_helper.rb'

class ModelTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  # TODO: Avoid rescued fixture require_dependency failure
  fixtures :users, :attachments, :attachment_blobs

  FIXTURE_FILE_STORE = File.join(RAILS_ROOT, 'test', 'fixtures', 'attachments')

  def setup
    FileUtils.mkdir Attachment::FILE_STORE
    FileUtils.cp_r File.join(FIXTURE_FILE_STORE, '.'), Attachment::FILE_STORE
    @ao = Attachment.attachment_options.dup
  end

  def teardown
    Attachment.attachment_options = @ao
    FileUtils.rm_rf Attachment::FILE_STORE
  end

  def test_create_attachment_via_file_with_no_aspects
    assert_difference 'Attachment.count' do
      a = Attachment.create(:file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary), :_aspects => [])
      assert a.valid?, a.errors.full_messages.first
      assert_equal 'SperrySlantStar.bmp', a.filename
      assert_not_nil a.digest
      assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
      assert_equal 4534, a.size
      assert a.aspects.empty?
      assert a.uri.absolute?
      assert_equal 'file', a.uri.scheme
    end
  end
  
  def test_create_with_empty_file
    assert_difference 'Attachment.count' do
      a = Attachment.create(:file => fixture_file_upload('attachments/empty.txt', 'text/plain'), :_aspects => [])
      assert a.valid?, a.errors.full_messages.first  # Attachment.attachment_options
      assert_equal 'empty.txt', a.filename
      assert_not_nil a.digest
      assert_equal "1B2M2Y8AsgTpgAmY7PhCfg==", Base64.encode64(a.digest).chomp!  # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))).chomp!
      assert_equal 0, a.size
      assert a.aspects.empty?
      assert a.uri.absolute?
      assert_equal 'file', a.uri.scheme
    end    
  end
  
  # Do attachments holding rehydrated sources behave?
  def test_source_rehydration
    a = attachments(:one)
    assert_not_nil a.source
    assert_equal 630, a.blob.size
  end

  def test_create_attachment_via_url_with_no_aspects
    url = "http://cho.hapgoods.com/wordpress"
    assert_difference 'Attachment.count' do
      a = Attachment.create(:url => url, :_aspects => [])
      assert a.valid?, a.errors.full_messages.first
      assert_equal url, a.url
      assert a.aspects.empty?
    end
  end

  def test_create_system_attachment_via_file_with_default_aspect
    Attachment.attachment_options[:_aspects] = [:thumbnail]
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary))
      assert a.valid?, a.errors.full_messages.first
      assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))
      assert_equal 4534, a.size
    end
  end

  def test_create_attachment_via_file_with_explicit_aspects
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:file => fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary), :_aspects => [:thumbnail])
      assert a.valid?, a.errors.full_messages.first
      assert_equal 'NxzAvUsuKjk8tPhbnbgLjQ==', Base64.encode64(a.digest).chomp! # Base64.encode64(Digest::MD5.digest(File.read('test/fixtures/attachments/AlexOnBMW#4.jpg')))
      assert_equal "320x256", a.image_size
      assert_equal 25535, a.blob.size
      assert_equal 25535, a.size
      assert_equal 320, a.metadata[:width]
      assert_equal 256, a.metadata[:height]
      assert_equal 'file', a.uri.scheme
      assert a.metadata.any?
      assert a.metadata.has_key?(:time)
      assert a.metadata[:time].acts_like?(:time)
      aspect = a.aspects.find_by_aspect('thumbnail')
      assert_equal 128, aspect.metadata[:width]
      assert_equal 102, aspect.metadata[:height]
      assert_operator 4616..4636, :include?, aspect.size
      assert_operator 4616..4636, :include?, aspect.blob.size
    end
  end

  def test_create_attachment_via_url_with_default_aspects
    Attachment.attachment_options[:_aspects] = [:thumbnail]
    assert_difference 'Attachment.count', 2 do
      url = 'http://www.memoryminer.com/graphics/missingphoto.jpg'
      a = Attachment.create(:url => url)
      assert a.valid?, a.errors.full_messages.first
      assert_not_nil a.filename
      assert_equal "missingphoto.jpg", a.filename
      assert_kind_of GroupSmarts::Attach::Sources::EXIFR, a.source # Confirm we optimistically fetched the source and extracted info
      assert_equal url, a.url
      assert_not_nil a.metadata
      assert_equal "800x600", a.image_size
      assert a.aspects.any?
      aspect = a.aspects.find_by_aspect('thumbnail')
      assert_equal "128x96", aspect.image_size
      assert_equal "image/jpeg", aspect.content_type
      # TODO: Validate this aspect further.
    end
  end

  def test_create_attachment_via_url_with_aspect_url
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:url => 'http://cho.hapgoods.com/icons/powered_by_fedora.png', :_aspects => {:thumbnail => {:url => 'http://cho.hapgoods.com/icons/apache_pb2.gif'}})
      assert a.valid?, a.errors.full_messages.first
      assert_equal 3034, a.size
      assert_kind_of GroupSmarts::Attach::Sources::Http, a.source # Confirm we didn't fetch the source
      assert_not_nil aspect = a.aspects.find_by_aspect('thumbnail')
    end
  end

  def test_create_attachment_via_url_with_aspect_file
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:url => 'http://cho.hapgoods.com/wordpress/', :_aspects => {:thumbnail => {:file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)}})
      assert a.valid?, a.errors.full_messages.first
      assert a.aspects.any?
    end
  end
  
  # Classic problems here include caching sources in a limited high-performance mode during validation only to find that all data is required later.
  # Also state variables (store, _aspects) in the attach instance methods are tricky to keep in sync during assignment.
  def test_validation_independence
    assert_nothing_raised do
      a = Attachment.new(:file => fixture_file_upload('/attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary))
      assert a.valid?
      a.save!
    end
  end

  def test_create_attachment_with_malformed_url
    assert_raises URI::InvalidURIError do
      a = Attachment.create(:url => "http://")
    end
  end

  # Should only create one attachment as the URL could not be retrieved and thus the default aspects are not built.
  def test_create_attachment_with_preloaded_data
    assert_difference 'Attachment.count', 1 do
      a = Attachment.create(:uri => "http:/www.memoryminer.com/bogusresource.jpg", :size => 10240, :content_type => 'image/jpg', :_aspects => [])
    end
  end

  # Both the aspect and the primary URL are not (yet) valid, but valid metadata is present.
  def test_create_attachment_with_preloaded_data_and_aspect
    assert_difference 'Attachment.count', 2 do
      tparms = {:thumbnail => {:uri => "http://www.memoryminer.com/bogusresource-t.jpg", :size => 1024, :content_type => 'image/jpg'}}
      aparms = {:uri => "http://www.memoryminer.com/bogusresource.jpg", :size => 10240, :content_type => 'image/jpg', :_aspects => tparms}
      a = Attachment.create(aparms)
    end
  end

  def test_source_required_on_save
    assert_no_difference 'Attachment.count' do
      a = Attachment.new({})
      a.save
      assert a.errors.any?
    end
  end
  
  def test_single_source_required
    assert_no_difference 'Attachment.count' do
      assert_raise RuntimeError do
        a = Attachment.new({:url => 'http://www.memoryminer.com/', :file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary)})
        a.save
      end
    end
  end
  
  def test_delete_simple
    assert_difference 'Attachment.count', -1 do
      assert_difference 'GroupSmarts::Attach::AttachmentBlob.count', -1 do #DbFile.count
        res = attachments(:sss).destroy
      end
    end
  end
  
  def test_delete_with_aspects
    res = attachments(:one)
    assert 1, res.aspects.size
    assert_difference 'Attachment.count', -2 do # Deletes child aspect as well.
      res.destroy
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
    a = Attachment.create(:file => fixture_file_upload('attachments/AlexOnBMW#4.jpg', 'image/jpeg', :binary), :_aspects => {})
    assert a.metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 -0500'), a.metadata[:time].to_time
  end
  
  def test_explicit_iconify_on_new
    a = Attachment.create(:file => fixture_file_upload('attachments/ManagingAgileProjects.pdf', 'application/pdf', :binary), :_aspects => [:icon])
    assert_equal 1, a.aspects.size
    assert i = a.aspects.find_by_aspect('icon')
    assert_match /application_pdf\.png/, i.uri.path
    assert_nil i.uri.scheme
  end
  
  def test_update
    url = "http://www.rubyonrails.org/images/rails.png"
    attachments(:sss).update_attributes({:url => url})
    assert_equal url, attachments(:sss).url
  end
  
  def test_update_attachment_updates_aspect
    Attachment.attachment_options[:_aspects] = [:thumbnail]
    url = "http://www.rubyonrails.org/images/rails.png"
    fn = attachments(:one_thumbnail).uri.path
    assert File.exists?(fn)
    a = attachments(:one)
    a.update_attributes({:url => url})
    assert a.valid?
    assert_equal url, a.url
    assert_equal url, a.uri.to_s
    assert_equal 1, a.aspects.size
    assert_not_equal fn, a.aspects.first.uri.path
    assert !File.exists?(fn)
  end
  
  def test_create_aspect_post_facto
    assert_difference 'Attachment.count' do
      Attachment.create(:file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary), :parent_id => attachments(:sss).id, :aspect => '*proof')
    end
    assert_equal 1, attachments(:sss).aspects.size
    assert a = attachments(:sss).aspects.first
    assert_equal "*proof", a.aspect
    assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))
    assert_equal 4534, a.size
  end

  def test_generate_reasonable_storage_uri_even_with_unreasonable_attributes
    a = Attachment.create(:file => fixture_file_upload('attachments/ManagingAgileProjects.pdf', 'example/example', :binary), :_aspects => [])
    p = Pathname.new(a.uri.path)
    assert_operator 128, :>, p.to_s.size
    assert_no_match /example\/example/, p.to_s  # make sure bogus Mime::Type does not appear literally in path.
  end
  
  def test_before_save_aspect_callback
    Attachment.attachment_options[:_aspects] = [:thumbnail]
    assert_difference 'Attachment.count', 2 do
      a = Attachment.create(:file => fixture_file_upload('attachments/SperrySlantStar.bmp', 'image/bmp', :binary))
      assert a.valid?, a.errors.full_messages.first
      assert_equal "ge5u7B+cjoGzXxRpeXzAzA==", Base64.encode64(a.digest).chomp!  # Digest::MD5.digest(File.read('test/fixtures/attachments/SperrySlantStar.bmp'))
      assert_equal 4534, a.size
    end    
  end
end