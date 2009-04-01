require File.dirname(__FILE__) + '/../test_helper'

class TaggingTest < ActiveSupport::TestCase
  fixtures :tags, :taggings, <%= taggable_models[0..1].join(", ") -%>

  def setup
    @objs = <%= model_two %>.find(:all, :limit => 2)
    
    @obj1 = @objs[0]
    @obj1.tag_with("pale")
    @obj1.reload
    
    @obj2 = @objs[1]
    @obj2.tag_with("pale imperial")
    @obj2.reload
    
<% if taggable_models.size > 1 -%>
    @obj3 = <%= model_one -%>.find(:first)
<% end -%>
    @tag1 = Tag.find(1)  
    @tag2 = Tag.find(2)  
    @tagging1 = Tagging.find(1)
  end

  def test_tag_with
    @obj2.tag_with "hoppy pilsner"
    assert_equal "hoppy pilsner", @obj2.tag_list
  end
  
  def test_find_tagged_with
    @obj1.tag_with "seasonal lager ipa"
    @obj2.tag_with ["lager", "stout", "fruity", "seasonal"]
    
    result1 = [@obj1]
    assert_equal <%= model_two %>.tagged_with("ipa"), result1
    assert_equal <%= model_two %>.tagged_with("ipa lager"), result1
    assert_equal <%= model_two %>.tagged_with("ipa", "lager"), result1
    
    result2 = [@obj1.id, @obj2.id].sort
    assert_equal <%= model_two %>.tagged_with("seasonal").map(&:id).sort, result2
    assert_equal <%= model_two %>.tagged_with("seasonal lager").map(&:id).sort, result2
    assert_equal <%= model_two %>.tagged_with("seasonal", "lager").map(&:id).sort, result2
  end
  
<% if options[:self_referential] -%>  
  def test_self_referential_tag_with
    @tag1.tag_with [1, 2]
    assert @tag1.tags.any? {|obj| obj == @tag1}
    assert !@tag2.tags.any? {|obj| obj == @tag1}
  end

<% end -%>
  def test__add_tags
    @obj1._add_tags "porter longneck"
    assert Tag.find_by_name("porter").taggables.any? {|obj| obj == @obj1}
    assert Tag.find_by_name("longneck").taggables.any? {|obj| obj == @obj1}
    assert_equal "longneck pale porter", @obj1.tag_list    
    
    @obj1._add_tags [2]
    assert_equal "imperial longneck pale porter", @obj1.tag_list        
  end
  
  def test__remove_tags
    @obj2._remove_tags ["2", @tag1]
    assert @obj2.tags.empty?
  end
  
  def test_tag_list
    assert_equal "imperial pale", @obj2.tag_list
  end
    
  def test_taggable
    assert_raises(RuntimeError) do 
      @tagging1.send(:taggable?, true) 
    end
    assert !@tagging1.send(:taggable?)
<% if taggable_models.size > 1 -%>
    assert @obj3.send(:taggable?)
<% end -%>
<% if options[:self_referential] -%>  
    assert @tag1.send(:taggable?)
<% end -%>    
  end
    
end
