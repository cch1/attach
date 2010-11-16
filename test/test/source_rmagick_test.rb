require File.dirname(__FILE__) + '/test_helper.rb'

class SourceRmagickTest < ActiveSupport::TestCase
  def test_process_thumbnail_with_rmagick
    s = stubbed_source(:filename => 'AlexOnBMW#4.jpg')
    assert s = Hapgood::Attach::Sources::Base.process(s, :thumbnail)
    assert_equal 128, s.metadata[:width]
    assert_equal 102, s.metadata[:height]
    assert_operator 4616..4636, :include?, s.size
    assert_operator 4616..4636, :include?, s.blob.size
  end
end