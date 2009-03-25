require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class NotEqualTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::NotEqual.new(Account, :column => Account.columns_hash["id"])
      condition.value = 12
      assert_equal ["\"accounts\".\"id\" != ?", 12], condition.sanitize
    
      condition = Searchlogic::Condition::NotEqual.new(Account, :column => Account.columns_hash["id"])
      condition.value = [1,2,3,4]
      assert_equal ["\"accounts\".\"id\" NOT IN (?)", [1, 2, 3, 4]], condition.sanitize
    
      condition = Searchlogic::Condition::NotEqual.new(Account, :column => Account.columns_hash["id"])
      condition.value = (1..10)
      assert_equal ["\"accounts\".\"id\" NOT BETWEEN ? AND ?", 1, 10], condition.sanitize
    end
  end
end