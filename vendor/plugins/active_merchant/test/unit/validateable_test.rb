require 'test_helper'

class Dood
  include ActiveMerchant::Validateable

  attr_accessor :name, :email, :country

  def validate
    errors.add "name", "cannot be empty" if name.blank?
    errors.add "email", "cannot be empty" if email.blank?
    errors.add_to_base "The country cannot be blank" if country.blank?
  end

end

class ValidateableTest < Test::Unit::TestCase
  include ActiveMerchant
  
  def setup
    @dood = Dood.new
  end

  def test_validation  
    assert ! @dood.valid?
    assert ! @dood.errors.empty?
  end

  def test_assigns 
    @dood = Dood.new(:name => "tobi", :email => "tobi@neech.de", :country => 'DE')

    assert_equal "tobi", @dood.name 
    assert_equal "tobi@neech.de", @dood.email
    assert @dood.valid?
  end

  def test_multiple_calls
    @dood.name = "tobi"        
    assert !@dood.valid?    
    
    @dood.email = "tobi@neech.de"    
    assert !@dood.valid?
    
    @dood.country = 'DE'
    assert @dood.valid?
  end

  def test_messages
    @dood.valid?
    assert_equal "cannot be empty", @dood.errors.on('name')
    assert_equal "cannot be empty", @dood.errors.on('email')
    assert_equal nil, @dood.errors.on('doesnt_exist')

  end

  def test_full_messages
    @dood.valid?
    assert_equal ["Email cannot be empty", "Name cannot be empty", "The country cannot be blank"], @dood.errors.full_messages.sort
  end

end
