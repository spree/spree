require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class GreaterThanOrEqualToTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::GreaterThanOrEqualTo.new(Account, :column => Account.columns_hash["id"])
      condition.value = 2
      assert_equal ["\"accounts\".\"id\" >= ?", 2], condition.sanitize
    end
  end
end