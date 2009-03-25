require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class ChildOfTest < ActiveSupport::TestCase
    def test_sanitize
      ben = users(:ben)
      
      condition = Searchlogic::Condition::ChildOf.new(User)
      condition.value = ben.id
      assert_equal ["\"users\".\"parent_id\" = ?", ben.id], condition.sanitize

      condition = Searchlogic::Condition::ChildOf.new(User)
      condition.value = ben
      assert_equal ["\"users\".\"parent_id\" = ?", ben.id], condition.sanitize
    end
  end
end