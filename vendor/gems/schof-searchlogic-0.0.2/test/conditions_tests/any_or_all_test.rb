require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionsTests
  class AnyOrAllTest < ActiveSupport::TestCase
    def test_any
      conditions = Searchlogic::Cache::AccountConditions.new
      assert !conditions.any?
      conditions = Searchlogic::Cache::AccountConditions.new(:any => true)
      assert conditions.any?
      conditions.any = "false"
      assert !conditions.any?
      conditions = Searchlogic::Cache::AccountConditions.new
      conditions.name_contains = "Binary"
      assert_equal ["\"accounts\".\"name\" LIKE ?", "%Binary%"], conditions.sanitize
      conditions.id = 1
      assert_equal ["\"accounts\".\"name\" LIKE ? AND \"accounts\".\"id\" = ?", "%Binary%", 1], conditions.sanitize
      conditions.any = true
      assert_equal ["\"accounts\".\"name\" LIKE ? OR \"accounts\".\"id\" = ?", "%Binary%", 1], conditions.sanitize
      conditions.any = false
      assert_equal ["\"accounts\".\"name\" LIKE ? AND \"accounts\".\"id\" = ?", "%Binary%", 1], conditions.sanitize
    end
  end
end