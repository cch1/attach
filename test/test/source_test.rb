require File.dirname(__FILE__) + '/test_helper.rb'

class SourceTest < ActiveSupport::TestCase
  include ActionController::TestProcess

  include ActionView::Helpers::AssetTagHelper

  def test_process_thumbnail_with_rmagick
    s = stubbed_source(:filename => 'AlexOnBMW#4.jpg')
    assert s = Hapgood::Attach::Sources::Base.process(s, :thumbnail)
    assert_equal 128, s.metadata[:width]
    assert_equal 102, s.metadata[:height]
    assert_operator 4616..4636, :include?, s.size
    assert_operator 4616..4636, :include?, s.blob.size
  end

  def test_process_info_with_exifr
    s = stubbed_source(:filename => 'AlexOnBMW#4.jpg')
    assert s.mime_type
    assert s = Hapgood::Attach::Sources::Base.process(s, :info)
    assert s.metadata[:time].is_a?(Time)
    assert_equal Time.parse('Sat, 28 Nov 1998 11:39:37 -0500'), s.metadata[:time].to_time
  end
end