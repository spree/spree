require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class EqualsTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::Equals.new(Account, :column => Account.columns_hash["id"])
      condition.value = 12
      assert_equal ["\"accounts\".\"id\" = ?", 12], condition.sanitize
    
      condition = Searchlogic::Condition::Equals.new(Account, :column => Account.columns_hash["id"])
      condition.value = [1,2,3,4]
      assert_equal ["\"accounts\".\"id\" IN (?)", [1, 2, 3, 4]], condition.sanitize
      
      condition = Searchlogic::Condition::Equals.new(Account, :column => Account.columns_hash["id"])
      condition.value = []
      assert_equal [], condition.value
      assert_nil condition.sanitize
      
      search = User.new_search
      search.conditions.id = []
      assert_equal [], search.conditions.id
    
      condition = Searchlogic::Condition::Equals.new(Account, :column => Account.columns_hash["id"])
      condition.value = (1..10)
      assert_equal ["\"accounts\".\"id\" BETWEEN ? AND ?", 1, 10], condition.sanitize
    end
  end
end