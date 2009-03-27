require File.dirname(__FILE__) + '/../test_helper.rb'

module ConditionsTests
  class DayOfMonthTest < ActiveSupport::TestCase
    def test_modifier_names
      
    end
    
    def test_usage
      search = User.new_search
      search.conditions.dom_of_created_at_gt = "1"
      assert_equal({:conditions => ["(strftime('%d', \"users\".\"created_at\") * 1) > ?", 1], :limit => 25}, search.sanitize)
      search.all
    end
  end
end