require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionTests
  class SiblingOfTest < ActiveSupport::TestCase
    def test_sanitize
      ben = users(:ben)
      drew = users(:drew)
      jennifer = users(:jennifer)
      
      condition = Searchlogic::Condition::SiblingOf.new(User)
      condition.value = drew
      assert_equal ["\"users\".\"id\" != ? AND \"users\".\"parent_id\" = ?", drew.id, ben.id], condition.sanitize
    end
  end
end