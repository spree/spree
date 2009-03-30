require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class NotNilTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::NotNil.new(Account, :column => Account.columns_hash["created_at"])
      condition.value = "1"
      assert_equal "\"accounts\".\"created_at\" IS NOT NULL", condition.sanitize
      condition.value = "false"
      assert_equal "\"accounts\".\"created_at\" IS NULL", condition.sanitize
    end
  end
end