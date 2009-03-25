require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class LikeTest < ActiveSupport::TestCase
    def test_sanitize
      condition = Searchlogic::Condition::Like.new(Account, :column => Account.columns_hash["name"])
      condition.value = "Binary and blah"
      assert_equal ["\"accounts\".\"name\" LIKE ?", "%Binary and blah%"], condition.sanitize
    end
  end
end