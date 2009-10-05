require 'test_helper'

class UtilsTest < Test::Unit::TestCase
  def test_unique_id_should_be_32_chars_and_alphanumeric
    assert_match /^\w{32}$/, ActiveMerchant::Utils.generate_unique_id
  end
end