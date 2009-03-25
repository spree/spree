require File.dirname(__FILE__) + '/../test_helper.rb'

module SearchTests
  class BaseTest < ActiveSupport::TestCase
    def test_needed
      assert Searchlogic::Search::Base.needed?(Account, :page => 2, :conditions => {:name => "Ben"})
      assert !Searchlogic::Search::Base.needed?(Account, :conditions => {:name => "Ben"})
      assert Searchlogic::Search::Base.needed?(Account, :limit => 2, :conditions => {:name_contains => "Ben"})
      assert !Searchlogic::Search::Base.needed?(Account, :limit => 2)
      assert Searchlogic::Search::Base.needed?(Account, :per_page => 2)
    end

    def test_initialize
      assert_nothing_raised { Account.new_search }
      search = Account.new_search!(:conditions => {:name_like => "binary"}, :page => 2, :limit => 10, :readonly => true)
      assert_equal Account, search.klass
      assert_equal "binary", search.conditions.name_like
      assert_equal 2, search.page
      assert_equal 10, search.limit
      assert_equal true, search.readonly
    end
  
    def test_acting_as_filter
      search = Account.new_search
      search.acting_as_filter = true
      assert search.acting_as_filter?
      search.acting_as_filter = false
      assert !search.acting_as_filter?
    end

    def test_setting_first_level_options
      search = Account.new_search!(:include => :users, :joins => :users, :offset => 5, :limit => 20, :order => "name ASC", :select => "name", :readonly => true, :group => "name", :from => "accounts", :lock => true)
      assert_equal :users, search.include
      assert_equal :users, search.joins
      assert_equal 5, search.offset
      assert_equal 20, search.limit
      assert_equal "name ASC", search.order
      assert_equal "name", search.select
      assert_equal true, search.readonly
      assert_equal "name", search.group
      assert_equal "accounts", search.from
      assert_equal true, search.lock
    
      search = Account.new_search(:per_page => nil)
  
      search.include = :users
      assert_equal :users, search.include
    
      # treat it like SQL, just like AR
      search.joins = "users"
      assert_equal "users", search.joins
  
      search.page = 5
      assert_equal 1, search.page
      assert_nil search.offset
  
      search.limit = 20
      assert_equal search.limit, 20
      assert_equal search.per_page, 20
      assert_equal search.page, 5
      assert_equal search.offset, 80
      search.limit = nil
      assert_nil search.limit
      assert_nil search.per_page
      assert_equal 1, search.page
      assert_nil search.offset
  
      search.offset = 50
      assert_equal 50, search.offset
      assert_equal 1, search.page
      search.limit = 50
      assert_equal 2, search.page
      search.offset = nil
      assert_nil search.offset
      assert_equal 1, search.page
  
      search.per_page = 2
      assert_equal 2, search.per_page
      assert_equal 2, search.limit
      search.offset = 50
      assert_equal 26, search.page
      assert_equal 50, search.offset
  
      search.order = "name ASC"
      assert_equal search.order, "name ASC"
  
      search.select = "name"
      assert_equal search.select, "name"
  
      search.readonly = true
      assert_equal search.readonly, true
  
      search.group = "name"
      assert_equal search.group, "name"
  
      search.from = "accounts"
      assert_equal search.from, "accounts"
  
      search.lock = true
      assert_equal search.lock, true
    end

    def test_joins
      search = Account.new_search
      assert_nil search.joins
      search.conditions.name_contains = "Binary"
      assert_nil search.joins
      search.conditions.users.first_name_contains = "Ben"
      assert_equal(:users, search.joins)
      search.conditions.users.orders.id_gt = 2
      assert_equal({:users => :orders}, search.joins)
      search.conditions.users.reset_orders!
      assert_equal(:users, search.joins)
      search.conditions.users.orders.id_gt = 2
      search.conditions.reset_users!
      assert_nil search.joins
    end

    def test_limit
      search = Account.new_search
      search.limit = 10
      assert_equal 10, search.limit
      search.page = 2
      assert_equal 10, search.offset
      search.limit = 25
      assert_equal 25, search.offset
      assert_equal 2, search.page
      search.page = 5
      assert_equal 5, search.page
      assert_equal 25, search.limit
      search.limit = 3
      assert_equal 12, search.offset
    end

    def test_options
    end

    def test_sanitize
      search = Account.new_search
      search.per_page = 2
      search.conditions.name_like = "Binary"
      search.conditions.users.id_greater_than = 2
      search.page = 3
      search.readonly = true
      assert_equal({:select => "DISTINCT \"accounts\".*", :joins => :users, :offset => 4, :readonly => true, :conditions => ["\"accounts\".\"name\" LIKE ? AND \"users\".\"id\" > ?", "%Binary%", 2], :limit => 2 }, search.sanitize)
    end

    def test_scope
      search = Account.new_search!
      search.conditions = "some sql"
      conditions = search.conditions
      assert_equal "some sql", search.conditions.conditions
      search.conditions = nil
      assert_equal({}, search.conditions.conditions)
      search.conditions = "some sql"
      assert_equal "some sql", search.conditions.conditions
      search.conditions = "some sql"
      assert_equal "some sql", search.conditions.conditions
    end

    def test_searching
      binary_logic = accounts(:binary_logic)
      neco = accounts(:neco)
      binary_fun = accounts(:binary_fun)
      
      search = Account.new_search
      search.conditions.name_like = "Binary"
      assert_equal [binary_logic, binary_fun], search.all
      assert_equal [binary_logic, binary_fun], search.find(:all)
      assert_equal binary_logic, search.first
      assert_equal binary_logic, search.find(:first)
  
      search.per_page = 20
      search.page = 2
  
      assert_equal [], search.all
      assert_equal [], search.find(:all)
      assert_nil search.first
      assert_nil search.find(:first)
      
      search.per_page = 0
      search.page = nil
      search.conditions.users.first_name_contains = "Ben"
      search.conditions.users.orders.description_keywords = "products, &*ap#ple $%^&*"
      assert_equal [binary_logic], search.all
      assert_equal [binary_logic], search.find(:all)
      assert_equal binary_logic, search.first
      assert_equal binary_logic, search.find(:first)
    
      search = Account.new_search
      search.select = "id, name"
      assert_equal Account.all, search.all
    
      search = Account.scope1.new_search!(:conditions => {:users => {:first_name_starts_with => "Ben"}})
      assert_equal [binary_logic], search.all
      search2 = search.dup
      assert_equal [binary_logic], search2.all
    end

    def test_calculations
      binary_logic = accounts(:binary_logic)
      binary_fun = accounts(:binary_fun)
      bens_order = orders(:bens_order)
      
      search = Account.new_search
      search.conditions.name_like = "Binary"
      assert_equal (binary_logic.id + binary_fun.id) / 2.0, search.average('id')
      assert_equal (binary_logic.id + binary_fun.id) / 2.0, search.calculate(:avg, 'id')
      assert_equal binary_fun.id, search.calculate(:max, 'id')
      assert_equal 2, search.count
      assert_equal binary_fun.id, search.maximum('id')
      assert_equal binary_logic.id, search.minimum('id')
      assert_equal binary_logic.id + binary_fun.id, search.sum('id')
    
      search.readonly = true
      assert_equal binary_logic.id + binary_fun.id, search.sum('id')
    
      search = Account.new_search(:conditions => {:users => {:orders => {:id_gt => bens_order.id}}})
      assert_equal 1, search.count

      search = Order.new_search(:conditions => {:user => {:account => {:id_gt => binary_logic.id}}})
      assert_equal 1, search.count
    
      search = UserGroup.new_search(:conditions => {:users => {:orders => {:id_gt => bens_order.id}}})
      assert_equal 1, search.count
    end
  
    def test_inspect
      search = Account.new_search
      assert_nothing_raised { search.inspect }
    end
  
    def test_sti
    
    end
    
    def test_include_in_relationships
      
    end
  end
end