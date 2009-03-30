require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class GreaterThanTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::GreaterThan.new(Account, :column => Account.columns_hash["id"])
      condition.value = 2
      assert_equal ["\"accounts\".\"id\" > ?", 2], condition.sanitize
    end
  end
end