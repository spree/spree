require File.dirname(__FILE__) + '/../test_helper'

class CVVResultTest < Test::Unit::TestCase
  def test_nil_data
    result = CVVResult.new(nil)
    assert_nil result.code
    assert_nil result.message
  end
  
  def test_blank_data
    result = CVVResult.new('')
    assert_nil result.code
    assert_nil result.message
  end
  
  def test_successful_match
    result = CVVResult.new('M')
    assert_equal 'M', result.code
    assert_equal CVVResult.messages['M'], result.message
  end
  
  def test_failed_match
    result = CVVResult.new('N')
    assert_equal 'N', result.code
    assert_equal CVVResult.messages['N'], result.message
  end
  
  def test_to_hash
    result = CVVResult.new('M').to_hash
    assert_equal 'M', result['code']
    assert_equal CVVResult.messages['M'], result['message']
  end
end