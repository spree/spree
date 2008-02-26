require File.dirname(__FILE__) + '/../test_helper'

class OptionGroupTest < Test::Unit::TestCase

  def test_invalid_with_empty_attributes
    option_group = OptionGroup.new
    assert !option_group.valid?
    assert option_group.errors.invalid?(:option)
    assert option_group.errors.invalid?(:option_value)
  end

end
