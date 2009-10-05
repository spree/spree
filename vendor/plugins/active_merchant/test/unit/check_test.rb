require 'test_helper'

class CheckTest < Test::Unit::TestCase
  VALID_ABA     = '111000025'
  INVALID_ABA   = '999999999'
  MALFORMED_ABA = 'I like fish'
  
  ACCOUNT_NUMBER = '123456789012'
  
  def test_validation
    c = Check.new
    assert !c.valid?
    assert !c.errors.empty?
  end
  
  def test_first_name_last_name
    check = Check.new(:name => 'Fred Bloggs')
    assert_equal 'Fred', check.first_name
    assert_equal 'Bloggs', check.last_name
    assert_equal 'Fred Bloggs', check.name
  end
  
  def test_nil_name
    check = Check.new(:name => nil)
    assert_nil check.first_name
    assert_nil check.last_name
    assert_equal "", check.name
  end
  
  def test_valid
    c = Check.new(:name => 'Fred Bloggs',
                  :routing_number => VALID_ABA,
                  :account_number => ACCOUNT_NUMBER,
                  :account_holder_type => 'personal',
                  :account_type => 'checking')
    assert c.valid?
  end
  
  def test_invalid_routing_number
    c = Check.new(:routing_number => INVALID_ABA)
    assert !c.valid?
    assert_equal c.errors.on(:routing_number), "is invalid"
  end
  
  def test_malformed_routing_number
    c = Check.new(:routing_number => MALFORMED_ABA)
    assert !c.valid?
    assert_equal c.errors.on(:routing_number), "is invalid"
  end
  
  def test_account_holder_type
    c = Check.new
    c.account_holder_type = 'business'
    c.valid?
    assert !c.errors.on(:account_holder_type)
    
    c.account_holder_type = 'personal'
    c.valid?
    assert !c.errors.on(:account_holder_type)
    
    c.account_holder_type = 'pleasure'
    c.valid?
    assert_equal c.errors.on(:account_holder_type), 'must be personal or business'
    
    c.account_holder_type = nil
    c.valid?
    assert !c.errors.on(:account_holder_type)
  end
  
  def test_account_type
    c = Check.new
    c.account_type = 'checking'
    c.valid?
    assert !c.errors.on(:account_type)
    
    c.account_type = 'savings'
    c.valid?
    assert !c.errors.on(:account_type)
    
    c.account_type = 'moo'
    c.valid?
    assert_equal c.errors.on(:account_type), "must be checking or savings"
    
    c.account_type = nil
    c.valid?
    assert !c.errors.on(:account_type)
  end
end
