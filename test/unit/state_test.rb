require 'test_helper'

class StateTest < ActiveSupport::TestCase
  should_validate_presence_of :country
  should_validate_presence_of :name
  should_allow_values_for :abbr, "NY"  
end