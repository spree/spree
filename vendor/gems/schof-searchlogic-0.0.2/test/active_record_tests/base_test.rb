require File.dirname(__FILE__) + '/../test_helper.rb'

module ActiveRecordTests
  class BaseTest < ActiveSupport::TestCase
    def test_standard_find
      binary_logic = accounts(:binary_logic)
      neco = accounts(:neco)
      binary_fun = accounts(:binary_fun)
      
      assert_equal [binary_logic, binary_fun, neco], Account.all
      assert_equal binary_logic, Account.first
      
      assert_equal [binary_logic, binary_fun, neco], Account.find(:all)
      assert_equal [binary_logic], Account.find(:all, :conditions => {:name => "Binary Logic"})
      assert_equal [binary_logic], Account.find(:all, :conditions => ["name = ?", "Binary Logic"])
      assert_equal [binary_logic], Account.find(:all, :conditions => "name = 'Binary Logic'")
      assert_equal binary_logic, Account.find(:first)
      assert_equal [binary_logic, binary_fun, neco], Account.find(:all, nil)
      assert_equal [binary_logic, binary_fun, neco], Account.find(:all, {})
      assert_equal [binary_logic, binary_fun, neco], Account.find(:all, :select => "id, name")
    end
    
    def test_standard_calculations
      binary_logic = accounts(:binary_logic)
      neco = accounts(:neco)
      binary_fun = accounts(:binary_fun)
      
      assert_equal 3, Account.count({})
      assert_equal 3, Account.count(nil)
      assert_equal 3, Account.count(:limit => 1)
      assert_equal 0, Account.count(:limit => 10, :offset => 10)
      assert_equal binary_logic.id + neco.id + binary_fun.id, Account.sum("id")
      assert_equal binary_logic.id + neco.id + binary_fun.id, Account.sum("id", {})
      assert_equal (binary_logic.id + neco.id + binary_fun.id) / 3.0, Account.average("id")
      assert_equal neco.id, Account.maximum("id")
      assert_equal binary_logic.id, Account.minimum("id")
    end
    
    def test_valid_ar_options
      assert_equal [:conditions, :include, :joins, :limit, :offset, :order, :select, :readonly, :group, :from, :lock], ActiveRecord::Base.valid_find_options
      assert_equal [:conditions, :joins, :order, :select, :group, :having, :distinct, :limit, :offset, :include, :from], ActiveRecord::Base.valid_calculations_options
    end
    
    def test_build_search
      search = Account.new_search(:conditions => {:name_keywords => "awesome"}, :page => 2, :per_page => 15)
      assert_kind_of Searchlogic::Search::Base, search
      assert_equal({}, search.scope)
      assert_equal Account, search.klass
      assert_equal "awesome", search.conditions.name_keywords
      assert_equal 2, search.page
      assert_equal 15, search.per_page
    end
    
    def test_searchlogic_searching
      binary_logic = accounts(:binary_logic)
      neco = accounts(:neco)
      binary_fun = accounts(:binary_fun)
      
      assert_equal [binary_logic, binary_fun], Account.all(:conditions => {:name_contains => "Binary"})
      assert_equal [binary_logic], Account.all(:conditions => {:name_contains => "Binary", :users => {:first_name_starts_with => "Ben"}})
      assert_equal [], Account.all(:conditions => {:name_contains => "Binary", :users => {:first_name_starts_with => "Ben", :last_name => "Mills"}})
      assert_equal [binary_logic, neco], Account.all(:conditions => {:users => {:id_gt => 0}}, :include => :users)
      
      read_only_accounts = Account.all(:conditions => {:name_contains => "Binary"}, :readonly => true)
      assert read_only_accounts.first.readonly?
      
      assert_equal [binary_logic, binary_fun], Account.all(:conditions => {:name_contains => "Binary"}, :page => 2)
      assert_equal [], Account.all(:conditions => {:name_contains => "Binary"}, :page => 2, :per_page => 20)
      
      assert_equal [binary_logic], Account.scope1.all(:conditions => {:users => {:first_name_starts_with => "Ben"}})
    end
    
    def test_searchlogic_counting
      assert_equal 2, Account.count(:conditions => {:name_contains => "Binary"})
      assert_equal 1, Account.count(:conditions => {:name_contains => "Binary", :users => {:first_name_contains => "Ben"}})
      assert_equal 1, Account.count(:conditions => {:name_contains => "Binary", :users => {:first_name_contains => "Ben"}}, :limit => 10, :offset => 10, :order_by => "id", :group => "accounts.id")
    end
    
    def test_scoping
      assert_equal({:conditions => {:name => "Binary"}, :limit => 10, :readonly => true}, Account.send(:with_scope, :find => {:conditions => {:name => "Binary"}, :limit => 10, :readonly => true}) { Account.send(:scope, :find) })
      assert_equal({:conditions => ["\"accounts\".\"name\" LIKE ?", "%Binary%"], :limit => 10, :offset => 20}, Account.send(:with_scope, :find => {:conditions => {:name_contains => "Binary"}, :per_page => 10, :page => 3}) { Account.send(:scope, :find) })
    end
    
    def test_accessible_conditions
      Account.conditions_accessible :name_contains
      assert_equal Set.new(["name_contains"]), Account.accessible_conditions
      Account.conditions_accessible :id_gt
      assert_equal Set.new(["id_gt", "name_contains"]), Account.accessible_conditions
      Account.conditions_accessible :id_gt, :name_contains
      assert_equal Set.new(["id_gt", "name_contains"]), Account.accessible_conditions
      Account.send(:write_inheritable_attribute, :conditions_accessible, nil)
    end
    
    def test_protected_conditions
      Account.conditions_protected :name_contains
      assert_equal Set.new(["name_contains"]), Account.protected_conditions
      Account.conditions_protected :id_gt
      assert_equal Set.new(["id_gt", "name_contains"]), Account.protected_conditions
      Account.conditions_protected :id_gt, :name_contains
      assert_equal Set.new(["id_gt", "name_contains"]), Account.protected_conditions
      Account.send(:write_inheritable_attribute, :conditions_protected, nil)
    end
    
    def test_includes
      assert_nothing_raised { Account.all(:conditions => {:users => {:first_name_like => "Ben"}}, :include => :users) }
    end
    
    def test_remove_duplicate_joins
      query = "SELECT DISTINCT `ticket_groups`.* FROM `ticket_groups` INNER JOIN tickets ON ticket_groups.id = tickets.ticket_group_id     LEFT OUTER JOIN `tickets` ON tickets.ticket_group_id = ticket_groups.id  WHERE (`tickets`.`id` = 2) AND ((`tickets`.event_id = 810802042))  LIMIT 20"
      cleaned_query = ActiveRecord::Base.send(:remove_duplicate_joins, query)
      expected_query = "SELECT DISTINCT `ticket_groups`.* FROM `ticket_groups` INNER JOIN tickets ON ticket_groups.id = tickets.ticket_group_id WHERE (`tickets`.`id` = 2) AND ((`tickets`.event_id = 810802042)) LIMIT 20"
      assert_equal expected_query, cleaned_query
    end
  end
end