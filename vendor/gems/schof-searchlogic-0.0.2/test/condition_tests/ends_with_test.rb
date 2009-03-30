require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class EndsWithTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::EndsWith.new(Account, :column => Account.columns_hash["name"])
      condition.value = "Binary"
      assert_equal ["\"accounts\".\"name\" LIKE ?", "%Binary"], condition.sanitize
    end
  end
end