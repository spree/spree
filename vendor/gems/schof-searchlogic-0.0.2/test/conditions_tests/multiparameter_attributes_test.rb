require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionsTests
  class MultiparameterAttributesTest < ActiveSupport::TestCase
    def test_conditions
      values = {"created_at(1i)" => "2004", "created_at(2i)" => "6", "created_at(3i)" => "24"}
      conditions = Searchlogic::Cache::AccountConditions.new(values)
      assert_equal ["\"accounts\".\"created_at\" = ?", Time.parse("Jun 24, 2004")], conditions.sanitize
      
      values = {"created_at_gt(1i)" => "2004", "created_at_gt(2i)" => "6", "created_at_gt(3i)" => "24"}
      conditions = Searchlogic::Cache::AccountConditions.new(values)
      assert_equal ["\"accounts\".\"created_at\" > ?", Time.parse("Jun 24, 2004")], conditions.sanitize
    end
  end
end