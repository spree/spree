require File.dirname(__FILE__) + '/../test_helper.rb'

module SearchTests
  class OrderingTest < ActiveSupport::TestCase
    def test_order_to_order_by
      search = Account.new_search
      search.order = "name"
      assert_equal "name", search.order_by
      search.order = "users.first_name"
      assert_equal({"users" => "first_name"}, search.order_by)
      search.order = "\"users\".\"first_name\""
      assert_equal({"users" => "first_name"}, search.order_by)
      search.order = "\"users\".\"first_name\", name ASC"
      assert_equal([{"users" => "first_name"}, "name"], search.order_by)
    end
  
    def test_order_by
      search = Account.new_search
      assert_nil search.order
      assert_nil search.order_by
    
      search.order_by = "first_name"
      assert_equal "first_name", search.order_by
      assert_equal "\"accounts\".\"first_name\"", search.order
    
      search.order_by = "last_name"
      assert_equal "last_name", search.order_by
      assert_equal "\"accounts\".\"last_name\"", search.order
    
      search.order_by = ["first_name", "last_name"]
      assert_equal ["first_name", "last_name"], search.order_by
      assert_equal "\"accounts\".\"first_name\", \"accounts\".\"last_name\"", search.order
    
      search.order = "created_at DESC"
      assert_equal "created_at", search.order_by
      assert_equal "created_at DESC", search.order
    
      search.order = "\"users\".updated_at ASC"
      assert_equal({"users" => "updated_at"}, search.order_by)
      assert_equal "\"users\".updated_at ASC", search.order
    
      search.order = "`users`.first_name DESC"
      assert_equal({"users" => "first_name"}, search.order_by)
      assert_equal "`users`.first_name DESC", search.order
    
      search.order = "`accounts`.name DESC"
      assert_equal "name", search.order_by
      assert_equal "`accounts`.name DESC", search.order
    
      search.order = "accounts.name DESC"
      assert_equal "name", search.order_by
      assert_equal "accounts.name DESC", search.order
    
      search.order = "`users`.first_name DESC, name DESC, `accounts`.id DESC"
      assert_equal [{"users" => "first_name"}, "name", "id"], search.order_by
      assert_equal "`users`.first_name DESC, name DESC, `accounts`.id DESC", search.order
    
      search.order = "`users`.first_name DESC, `line_items`.id DESC, `accounts`.id DESC"
      assert_equal [{"users" => "first_name"}, "id"], search.order_by
      assert_equal "`users`.first_name DESC, `line_items`.id DESC, `accounts`.id DESC", search.order
    
      search.order = "`line_items`.id DESC"
      assert_nil search.order_by
      assert_equal "`line_items`.id DESC", search.order
    end
  
    def test_order_as
      search = Account.new_search
      assert_nil search.order
      assert_nil search.order_as
      assert search.asc?
      assert !search.desc?
    
      search.order_as = "DESC"
      assert_nil search.order_as
      assert !search.desc?
      assert_nil search.order
    
      search.order_by = "name"
      assert_equal "\"accounts\".\"name\" DESC", search.order
    
      search.order_as = "ASC"
      assert_equal "\"accounts\".\"name\" ASC", search.order
      assert search.asc?
    
      search.order = "id ASC"
      assert_equal "ASC", search.order_as
      assert search.asc?
      assert_equal "id ASC", search.order
    
      search.order = "id DESC"
      assert_equal "DESC", search.order_as
      assert search.desc?
      assert_equal "id DESC", search.order
    
      search.order_by = "name"
      assert_equal "DESC", search.order_as
      assert search.desc?
      assert_equal "\"accounts\".\"name\" DESC", search.order
    
      assert_raise(ArgumentError) { search.order_as = "awesome" }
    end

    def test_order_by_auto_joins
      search = Account.new_search
      assert_nil search.order_by_auto_joins
      search.order_by = :name
      assert_nil search.order_by_auto_joins
      search.order_by = {:users => :first_name}
      assert_equal :users, search.order_by_auto_joins
      search.order_by = [{:users => :first_name}, {:orders => :total}, {:users => {:user_groups => :name}}]
      assert_equal [:users, :orders, {:users => :user_groups}], search.order_by_auto_joins
      search.priority_order_by = {:users => :first_name}
      assert_equal [:users, :orders, {:users => :user_groups}], search.order_by_auto_joins
      search.priority_order_by = {:users => {:orders => :total}}
      assert_equal({:users => :orders}, search.priority_order_by_auto_joins)
    end

    def test_priority_order_by
      search = Account.new_search
      assert_nil search.priority_order
      assert_nil search.priority_order_by
      assert_nil search.priority_order_as
    
      search.priority_order_by = :name
      assert_equal "\"accounts\".\"name\"", search.priority_order
      assert_equal "\"accounts\".\"name\"", search.sanitize[:order]
      assert_nil search.order
      assert_equal :name, search.priority_order_by
      assert_nil search.priority_order_as
    
      search.order_by = :id
      assert_equal "\"accounts\".\"name\", \"accounts\".\"id\"", search.sanitize[:order]
      search.order_as = "DESC"
      assert_equal "\"accounts\".\"name\", \"accounts\".\"id\" DESC", search.sanitize[:order]
    end
  
    def test_priority_order_as
      search = Account.new_search
      assert_nil search.priority_order_as
      assert_nil search.order_as
      search.priority_order_as = "ASC"
      assert_nil search.priority_order_as
      assert_nil search.order_as
      search.priority_order_by = :name
      assert_equal "ASC", search.priority_order_as
      assert_nil search.order_as
      search.priority_order_as = "DESC"
      assert_equal "DESC", search.priority_order_as
      assert_nil search.order_as
      assert_raise(ArgumentError) { search.priority_order_as = "awesome" }
      search.priority_order = nil
      assert_nil search.priority_order_as
      assert_nil search.order_as
    end
  
    def test_sanitize
      # tested in test_priority_order_by
    end
  
    def test_ordering_includes_blank
      search = User.new_search!
      search.order_by = {:account => :name}
      assert_equal 4, search.count
    end
  end
end
