require 'test_helper'

class CalculatorTest < ActiveSupport::TestCase
  should_belong_to :calculable
  should_validate_presence_of :calculable_id
end
