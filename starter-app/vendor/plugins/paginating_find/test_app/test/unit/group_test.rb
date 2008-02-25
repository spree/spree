require File.dirname(__FILE__) + '/abstract_test.rb'

class GroupTest < Test::Unit::TestCase
  def test_should_paginate_with_group
    one = Article.create(:name => "one", :author_id => 1)
    two = Article.create(:name => "two", :author_id => 1)
    three = Article.create(:name => "three", :author_id => 1)
    four = Article.create(:name => "four", :author_id => 2)
    results = Article.find(:all, :group => "author_id", :page => {:size => 2})
    assert_equal 2, results.size
    assert results.to_a.include?(one)
    assert !results.to_a.include?(two)
    assert !results.to_a.include?(three)
    assert results.to_a.include?(four)
    assert_equal 1, results.page_count
    assert_equal 2, results.page_size
  end
  
  def test_should_paginate_with_group_and_order
    one = Article.create(:name => "one", :author_id => 1)
    two = Article.create(:name => "two", :author_id => 1)
    three = Article.create(:name => "three", :author_id => 1)
    four = Article.create(:name => "four", :author_id => 2)
    results = Article.find(:all, :group => "author_id", :order => "name DESC", :page => {:size => 2})
    assert_equal 2, results.size
    assert_equal 1, results.page_count
    assert_equal 2, results.page_size
  end
  
  def test_should_work_with_having_tacked_onto_group
    one = Article.create(:name => "one", :author_id => 1)
    two = Article.create(:name => "two", :author_id => 1)
    three = Article.create(:name => "three", :author_id => 1)
    four = Article.create(:name => "four", :author_id => 2)
    results = Article.find(:all, :group => "author_id HAVING author_id=1", :order => "name DESC", :page => {:size => 2})
    assert_equal 1, results.size
    assert_equal 1, results.page_count
    assert_equal 2, results.page_size
  end
end