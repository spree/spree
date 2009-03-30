require File.dirname(__FILE__) + '/../test_helper.rb'

module ActiveRecordTests
  class AssociationsTest < ActiveSupport::TestCase
    def test_has_many
      binary_logic = accounts(:binary_logic)
      ben = users(:ben)
      jennifer = users(:jennifer)
      
      search = binary_logic.users.new_search
      assert_kind_of Searchlogic::Search::Base, search
      assert_equal User, search.klass
      assert_equal({:conditions => "\"users\".account_id = #{binary_logic.id}"}, search.scope)
      
      assert_equal [ben, jennifer], search.all
      assert_equal ben, search.first
      assert_equal ((ben.id + jennifer.id) / 2.0), search.average("id")
      assert_equal 2, search.count
    
      search.conditions.first_name_contains = "Ben"
    
      assert_equal [ben], search.all
      assert_equal ben, search.first
      assert_equal ben.id, search.average("id")
      assert_equal 1, search.count
    
      assert_equal 2, binary_logic.users.count
      assert_equal 1, binary_logic.users.all(:conditions => {:first_name_contains => "Ben"}).size
      assert_equal 0, binary_logic.users.all(:conditions => {:first_name_contains => "No one"}).size
      assert_equal ben.id, binary_logic.users.sum("id", :conditions => {:first_name_contains => "Ben"})
      assert_equal 0, binary_logic.users.sum("id", :conditions => {:first_name_contains => "No one"})
      assert_equal ben.id, binary_logic.users.average("id", :conditions => {:first_name_contains => "Ben"})
    end
  
    def test_has_many_through
      binary_logic = accounts(:binary_logic)
      
      search = binary_logic.orders.new_search
      assert_kind_of Searchlogic::Search::Base, search
      assert_equal Order, search.klass
      assert_equal({:joins => "INNER JOIN users ON orders.user_id = users.id   ", :conditions => "(\"users\".account_id = #{binary_logic.id})"}, search.scope)
      
      bens_order = orders(:bens_order)
      assert_equal [bens_order], search.all
      assert_equal bens_order, search.first
      assert_equal bens_order.id, search.average("id")
      assert_equal 1, search.count
    
      search.conditions.total_gt = 100
    
      assert_equal [bens_order], search.all
      assert_equal bens_order, search.first
      assert_equal bens_order.id, search.average("id")
      assert_equal 1, search.count
    
      assert_equal 1, binary_logic.orders.count
      assert_equal 1, binary_logic.orders.all(:conditions => {:total_gt => 100}).size
      assert_equal 0, binary_logic.orders.all(:conditions => {:total_gt => 1000}).size
      assert_equal bens_order.id, binary_logic.orders.sum("id", :conditions => {:total_gt => 100})
      assert_equal 0, binary_logic.orders.sum("id", :conditions => {:total_gt => 1000})
      assert_equal bens_order.id, binary_logic.orders.average("id", :conditions => {:total_gt => 100})
    end
  
    def test_habtm
      neco = user_groups(:neco)
      ben = users(:ben)
      drew = users(:drew)
      
      search = neco.users.new_search
      assert_kind_of Searchlogic::Search::Base, search
      assert_equal User, search.klass
      assert_equal({:conditions => "\"user_groups_users\".user_group_id = #{neco.id} ", :joins => "INNER JOIN \"user_groups_users\" ON \"users\".id = \"user_groups_users\".user_id"}, search.scope)
      assert_equal [drew, ben], search.all
      
      assert_equal drew, search.first
      assert_equal ((ben.id + drew.id) / 2.0).to_s, search.average("id").to_s
      assert_equal 2, search.count
    
      search.conditions.first_name_contains = "Ben"

      assert_equal [ben], search.all
      assert_equal ben, search.first
      assert_equal ben.id, search.average("id")
      assert_equal 1, search.count
    
      assert_equal 2, neco.users.count
      assert_equal 1, neco.users.all(:conditions => {:first_name_contains => "Ben"}).size
      assert_equal 0, neco.users.all(:conditions => {:first_name_contains => "No one"}).size
      assert_equal ben.id, neco.users.sum("id", :conditions => {:first_name_contains => "Ben"})
      assert_equal 0, neco.users.sum("id", :conditions => {:first_name_contains => "No one"})
      assert_equal ben.id, neco.users.average("id", :conditions => {:first_name_contains => "Ben"})
    end
  end
end
