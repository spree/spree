require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionsTests
  class GroupsTest < ActiveSupport::TestCase
    def test_group_object
      conditions = Searchlogic::Cache::AccountConditions.new
      conditions.id_gt = 3
      group1 = conditions.group
      group1.name_like = "Binary"
      group2 = conditions.group
      group2.id_gt = 5
      group21 = group2.group
      group21.id_lt = 20
      now = Time.now
      group21.created_at_after = now
      assert_equal ["\"accounts\".\"id\" > ? AND (\"accounts\".\"name\" LIKE ?) AND (\"accounts\".\"id\" > ? AND (\"accounts\".\"id\" < ? AND \"accounts\".\"created_at\" > ?))", 3, "%Binary%", 5, 20, now], conditions.sanitize
    end
    
    def test_group_block
      conditions = Searchlogic::Cache::AccountConditions.new
      conditions.id_gt = 3
      conditions.group do |group1|
        group1.name_like = "Binary"
      end
      now = Time.now
      conditions.group do |group2|
        group2.id_gt = 5
        group2.group do |group21|
          group21.id_lt = 20
          group21.created_at_after = now
        end
      end
      assert_equal ["\"accounts\".\"id\" > ? AND (\"accounts\".\"name\" LIKE ?) AND (\"accounts\".\"id\" > ? AND (\"accounts\".\"id\" < ? AND \"accounts\".\"created_at\" > ?))", 3, "%Binary%", 5, 20, now], conditions.sanitize
    end
    
    def test_group_hash
      now = Time.now
      conditions = Searchlogic::Cache::AccountConditions.new([
        {:id_gt => 3},
        {:group => {:name_like => "Binary"}},
        {:group => [
          {:id_gt => 5},
          {:group => [
            {:id_lt => 20},
            {:created_at_after => now}
          ]}
        ]}
      ])
      assert_equal ["\"accounts\".\"id\" > ? AND (\"accounts\".\"name\" LIKE ?) AND (\"accounts\".\"id\" > ? AND (\"accounts\".\"id\" < ? AND \"accounts\".\"created_at\" > ?))", 3, "%Binary%", 5, 20, now], conditions.sanitize
    end
    
    def test_auto_joins
      conditions = Searchlogic::Cache::AccountConditions.new
      conditions.group do |g|
        g.users.first_name_like = "Ben"
      end
      assert_equal :users, conditions.auto_joins
      
      search = Searchlogic::Cache::AccountSearch.new
      search.conditions.users.first_name_like = "Ben"
      search.conditions.group do |g|
        g.users.orders.id_gt = 5
      end
      assert_equal [:users, {:users => :orders}], search.conditions.auto_joins
      assert_nothing_raised { search.all }
    end
  end
end