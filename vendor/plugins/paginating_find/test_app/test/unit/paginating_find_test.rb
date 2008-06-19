require File.dirname(__FILE__) + '/abstract_test.rb'

class PaginatingFindTest < Test::Unit::TestCase
  fixtures :authors, :edits, :articles
  
  def test_should_not_bonk_on_marshal_dump
    results = Article.find(:all, :page => {:size => 2})
    Marshal.dump(results)
  end
  
  def test_should_preserve_enumerator_stats_on_marshal_load
    results = Article.find(:all, :page => {:size => 2})
    loaded = Marshal.load(Marshal.dump(results))
    assert_equal 2, loaded.page_size
    assert_equal Article.count, loaded.size
  end
  
  def test_should_auto_paginate
    h = ArticleHelper.new(112)
    h.find_articles(:all, :page => {:size => 10, :auto => true}) do |results|
      results.each {} # enumerate all 112 results
      assert_equal results.page_count, results.stop_page
      assert_equal results.page_count, results.page
    end
  end
  
  def test_should_paginate
    h = ArticleHelper.new(112)
    h.find_articles(:all, :page => {:size => 10}) do |results|
      results.each {} # enumerate first 10 results
      results.next_page! # move to next page
      results.page = 2
      results.each {} # enumerate next 10 results
    end
  end
  
  def test_should_not_paginate
    results = Article.find(:all)
    assert !results.respond_to?(:page_count)
    assert !results.respond_to?(:page_size)
  end
  
  def test_should_paginate_with_conditions
    h = ArticleHelper.new(20)
    h.find_articles(:all, :conditions => "name = 1", :order => "name ASC", :page => {:size => 10}) do |results|
      assert_equal 10, results.page_size
      assert_equal 1, results.size
      results.each {} 
      assert_equal 1, results.page
      end
  end
  
  def test_should_respect_limit
    h = ArticleHelper.new(80, 52)
    h.find_articles(:all, :limit => 52, :page => {:size => 10}) do |results|
      assert_equal 52, results.size
      assert_equal 10, results.page_size
    end
  end
  
  def test_should_not_query_for_count
    h = ArticleHelper.new(80, 50)
    h.find_articles(:all, :page => {:size => 10, :count => 50}) do |results|
      assert_equal 50, results.size
      assert_equal 10, results.page_size
    end
  end
  
  def test_should_use_limit_instead_of_count
    h = ArticleHelper.new(80, 41)
    h.find_articles(:all, :limit => 41, :page => {:size => 10, :count => 50}) do |results|
      assert_equal 41, results.size
      assert_equal 10, results.page_size
    end
  end
  
  def test_should_use_count_instead_of_limit
    h = ArticleHelper.new(80, 41)
    h.find_articles(:all, :limit => 50, :page => {:size => 10, :count => 41}) do |results|
      assert_equal 41, results.size
      assert_equal 10, results.page_size
    end
  end
  
  def test_should_respect_include
    results = Article.find(:all, 
                           :conditions => ["authors.id = ?", authors(:alex).id],
                           :include => [:author],
                           :page => {:size => 10})
    assert_equal 1, results.size
    assert_equal 10, results.page_size
    assert_equal authors(:alex), results.to_a.first.author
  end
  
  def test_should_correctly_count_through_associations
    editors = articles(:testing).editors.find(:all,
                                              :page => {:size => 20,
                                                        :first => 1,
                                                        :current => 1 })
    assert_equal 20, editors.page_size
    assert_equal articles(:testing).editors.count, editors.size  
    assert_equal articles(:testing).editors.count, editors.to_a.size                    
  end
  
  def test_should_respect_scope
    Article.find_with_scope({ :conditions => "name = 1" }) do
      h = ArticleHelper.new(20)
      h.find_articles(:all, :page => {:size => 10}) do |results|
        assert_equal 1, results.size
        assert_equal 1, results.to_a.size
        assert_equal 10, results.page_size
      end
    end
  end
  
  def test_should_respect_scope_with_include
    h = ArticleHelper.new(20)
    Article.find_with_scope({:conditions => "articles.name >= 1 and articles.name <= 3" }) do
      h.find_articles(:all, :include => [:author, :edits], :page => {:size => 10, :current => 1, :first => 1}, :order => "articles.name ASC") do |results|
        assert_equal 3, results.size
        assert_equal 3, results.to_a.size
        assert_equal 10, results.page_size
      end
    end
  end
  
  def test_should_respect_nested_scope
    h = ArticleHelper.new(20)
    Article.find_with_scope({ :conditions => "name = 1" }) do
      Article.find_with_scope({ :conditions => "name = 2" }) do
        h.find_articles(:all, :page => {:size => 10}) do |results|
          assert_equal 0, results.size
          assert_equal 0, results.to_a.size
          assert_equal 10, results.page_size
        end
      end  
    end
  end
  
  # =)
  def test_should_respect_out_of_scope_scope
    results = nil
    (1..20).each { |n| Article.create(:name => n, :author_id => 1) }
    Article.find_with_scope({ :conditions => "name >= 1 and name <= 15" }) do
      results = Article.find(:all, :page => {:size => 10, :auto => true})
    end
    assert_equal 10, results.page_size
    assert_equal 15, results.size
    assert_equal 15, results.to_a.size
  end
  
  def test_should_respect_out_of_scope_scope_with_include
    results = nil
    (1..20).each { |n| Article.create(:name => n, :author_id => 1) }
    Article.find_with_scope({ :conditions => "articles.name >= 1 and articles.name <= 15 and authors.id = 1", :include => [:author, :edits]}) do
      results = Article.find(:all, :page => {:size => 10, :auto => true})
    end
    assert_equal 10, results.page_size
    assert_equal 15, results.size
    assert_equal 15, results.to_a.size
  end
  
end

class ArticleHelper
  def initialize(how_many, limit=nil)
    @how_many = how_many
    @limit=limit
  end
  
  # Create n number of articles, and query them using the specified
  # arguments. Check that the correct number of pages were returned
  # and yield the results.
  #
  def find_articles(*args)
    (1..@how_many).each { |n| Article.create(:name => n, :author_id => 1) }
    results = Article.find(*args)
    if results.size > results.page_size
      page_count, num_on_last_page = how_many.divmod(results.page_size)
      page_count = page_count + 1 if num_on_last_page > 0
    else 
      page_count = 1
    end
    if (page_count != results.page_count)
      raise "Expected #{page_count} pages but there were #{results.page_count}"
    end  
    yield results if block_given? 
    results
  end
  
  def how_many
    @limit ? @limit : @how_many
  end
end