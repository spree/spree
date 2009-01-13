require File.dirname(__FILE__) + '/../test_helper'

class TagTest < Test::Unit::TestCase
  fixtures <%= taggable_models[0..1].join(", ") -%>
  
  def setup
    @obj = <%= model_two %>.find(:first)
    @obj.tag_with "pale imperial"
  end

  def test_to_s
    assert_equal "imperial pale", <%= model_two -%>.find(:first).tags.to_s
  end
  
end
