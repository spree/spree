require 'test_helper'

class CountryTest < ActiveSupport::TestCase
  should_validate_presence_of :name
  should_validate_presence_of :iso_name
end