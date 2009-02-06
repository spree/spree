require(File.join(File.dirname(__FILE__), 'test_helper'))

# TODO: make some nice mock objects!!!!!!!!!!!!!!!!!!
class Post < ActiveRecord::Base; end
class User < ActiveRecord::Base; end
class Article < ActiveRecord::Base; end

# TODO DO BETTER TESTING!!!! 
class FindByParamTest < Test::Unit::TestCase
  
  def test_default_should_return_id
    post = Post.create(:title=>"hey ho let's go!")
    assert_equal post.to_param, post.id.to_s
    assert_equal post.permalink, nil
  end
  
  def test_permalink_should_be_saved
    Post.class_eval "make_permalink :with => :title"
    post = Post.create(:title=>"hey ho let's go!")
    assert_equal "hey-ho-let-s-go", post.to_param
    assert_equal post.permalink, post.to_param
  end
  
  def test_permalink_should_be_trunkated
    Post.class_eval "make_permalink :with => :title"
    post = Post.create(:title=>"thisoneisaveryveryveryveryveryveryverylonglonglonglongtitlethisoneisaveryveryveryveryveryveryverylonglonglonglongtitle")
    assert_equal "thisoneisaveryveryveryveryveryveryverylonglonglong", post.to_param
    assert_equal post.to_param.size, 50
    assert_equal post.permalink, post.to_param
  end
  
  def test_permalink_should_be_trunkated_to_custom_size
    Post.class_eval "make_permalink :with => :title, :param_size=>10"
    post = Post.create(:title=>"thisoneisaveryveryveryveryveryveryverylonglonglonglongtitlethisoneisaveryveryveryveryveryveryverylonglonglonglongtitle")
    assert_equal "thisoneisa",post.to_param
    assert_equal post.permalink, post.to_param
  end
  
  def test_should_search_field_for_to_param_field
    User.class_eval "make_permalink :with => :login"
    user = User.create(:login=>"bumi")
    assert_equal user, User.find_by_param("bumi")
    assert_equal user, User.find_by_param!("bumi")
  end
  
  def test_should_validate_presence_of_the_field_used_to_create_the_param
    User.class_eval "make_permalink :with => :login"
    user = User.create(:login=>nil)
    assert_equal false, user.valid?
  end
  
  def test_to_param_should_perpend_id
    Article.class_eval "make_permalink :with => :title, :prepend_id=>true "
    article = Article.create(:title=>"hey ho let's go!")
    assert_equal article.to_param, "#{article.id}-hey-ho-let-s-go"
  end
  
  def test_should_increment_counter_if_not_unique
    Post.class_eval "make_permalink :with => :title"
    Post.create(:title=>"my awesome title!")
    post = Post.create(:title=>"my awesome title!")
    assert_equal "my-awesome-title-1", post.to_param
    assert_equal post.permalink, post.to_param
  end
  
  def test_should_record_not_found_error
    assert_raise(ActiveRecord::RecordNotFound) { Post.find_by_param!("isnothere") }
  end
  def test_should_return_nil_if_not_found
    assert_equal nil, Post.find_by_param("isnothere")
  end
  
  def test_escape_should_strip_special_chars
    assert_equal "+-he-l-l-o-ni-ce-duaode", Post.escape("+*(he/=&l$l<o !ni^?ce-`duäöde;:@")
  end
  
  def test_does_not_leak_options
    Post.class_eval "make_permalink :with => :title"
    User.class_eval "make_permalink :with => :login"
    Article.class_eval "make_permalink :with => :title, :prepend_id => true"
    assert_equal( {:param => "permalink", :param_size => 50, :field => "permalink", :prepend_id => false, :escape => true, :with => :title, :validate => true}, Post.permalink_options)
    
    assert_equal( {:param => :login, :param_size => 50, :field => "permalink", :prepend_id => false, :escape => true, :with => :login, :validate => true}, User.permalink_options)
    
    assert_equal( {:param => :title, :param_size => 50, :field => "permalink", :prepend_id => true, :escape => true, :with => :title, :validate => true}, Article.permalink_options)
  end
  
end
