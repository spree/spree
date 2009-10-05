require 'test_helper'

class MyPost < PostData
  self.required_fields = [ :ccnumber, :ccexp, :firstname, :lastname, :username, :password, :order_id, :key, :time ]
end

class PostDataTest < Test::Unit::TestCase
  
  def setup
    
  end
  
  def teardown
    PostData.required_fields = []
  end
  
  def test_element_assignment
    name = 'Cody Fauser'
    post = PostData.new
    
    post[:name] = name
    assert_equal name, post[:name]
  end
  
  def test_ignore_blank_fields
    post = PostData.new
    assert_equal 0, post.keys.size
    
    post[:name] = ''
    assert_equal 0, post.keys.size
    
    post[:name] = nil
    assert_equal 0, post.keys.size
  end
  
  def test_dont_ignore_required_blank_fields
    PostData.required_fields = [ :name ]
    post = PostData.new
    
    assert_equal 0, post.keys.size
    
    post[:name] = ''
    assert_equal 1, post.keys.size
    assert_equal '', post[:name]
    
    post[:name] = nil
    assert_equal 1, post.keys.size
    assert_nil post[:name]
  end
    
  def test_subclass
    post = MyPost.new
    assert_equal [ :ccnumber, :ccexp, :firstname, :lastname, :username, :password, :order_id, :key, :time ], post.required_fields
  end
end