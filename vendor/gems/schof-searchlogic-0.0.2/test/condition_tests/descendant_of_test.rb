require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class DescendantOfTest < ActiveSupport::TestCase
    def test_sanitize
      ben = users(:ben)
      condition = Searchlogic::Condition::DescendantOf.new(User)
      condition.value = ben
      assert_equal ["(\"users\".\"id\" != ? AND (\"users\".\"lft\" >= ? AND \"users\".\"rgt\" <= ?))", ben.id, ben.left, ben.right], condition.sanitize
    end
  end
end