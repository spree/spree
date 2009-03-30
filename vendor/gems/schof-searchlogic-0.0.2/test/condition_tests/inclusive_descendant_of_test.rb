require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class InclusiveDescendantOfTest < ActiveSupport::TestCase
    def test_sanitize
      ben = users(:ben)
      condition = Searchlogic::Condition::InclusiveDescendantOf.new(User)
      condition.value = ben
      assert_equal ["(\"users\".\"lft\" >= ? AND \"users\".\"rgt\" <= ?)", ben.left, ben.right], condition.sanitize
    end
  end
end