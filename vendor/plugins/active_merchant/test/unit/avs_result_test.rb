require 'test_helper'

class AVSResultTest < Test::Unit::TestCase
  def test_nil
    result = AVSResult.new(nil)
  end
  
  def test_no_match
    result = AVSResult.new(:code => 'N')
    assert_equal 'N', result.code
    assert_equal 'N', result.street_match
    assert_equal 'N', result.postal_match
    assert_equal AVSResult.messages['N'], result.message
  end
  
  def test_only_street_match
    result = AVSResult.new(:code => 'A')
    assert_equal 'A', result.code
    assert_equal 'Y', result.street_match
    assert_equal 'N', result.postal_match
    assert_equal AVSResult.messages['A'], result.message
  end
  
  def test_only_postal_match
    result = AVSResult.new(:code => 'W')
    assert_equal 'W', result.code
    assert_equal 'N', result.street_match
    assert_equal 'Y', result.postal_match
    assert_equal AVSResult.messages['W'], result.message
  end
  
  def test_nil_data
    result = AVSResult.new(:code => nil)
    assert_nil result.code
    assert_nil result.message
  end
  
  def test_empty_data
    result = AVSResult.new(:code => '')
    assert_nil result.code
    assert_nil result.message
  end
  
  def test_to_hash
    avs_data = AVSResult.new(:code => 'X').to_hash
    assert_equal 'X', avs_data['code']
    assert_equal AVSResult.messages['X'], avs_data['message']
  end
  
  def test_street_match
    avs_data = AVSResult.new(:street_match => 'Y')
    assert_equal 'Y', avs_data.street_match
  end
  
  def test_postal_match
    avs_data = AVSResult.new(:postal_match => 'Y')
    assert_equal 'Y', avs_data.postal_match
  end
end