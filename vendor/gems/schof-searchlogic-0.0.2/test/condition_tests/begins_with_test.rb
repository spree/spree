require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class BeginsWithTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::BeginsWith.new(Account, :column => Account.columns_hash["name"])
      condition.value = "Binary"
      assert_equal ["\"accounts\".\"name\" LIKE ?", "Binary%"], condition.sanitize
    end
  end
end