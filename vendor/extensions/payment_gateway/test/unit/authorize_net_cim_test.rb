require File.dirname(__FILE__) + '/../test_helper'

class AuthorizeNetCimTest < Test::Unit::TestCase

  def setup
    @cim_gateway = ActiveMerchant::Billing::AuthorizeNetCimGateway.new(
      :login => 'x',
      :password => 'y'
    )
    @country = Factory(:country, :name => "United States", :iso_name => "UNITED STATES", :iso3 => "USA", :iso => "US", :numcode => 840)
    @address = Factory(:address, 
      :firstname => 'John',
      :lastname => 'Doe',
      :address1 => '1234 My Street',
      :address2 => 'Apt 1',
      :city =>  'Washington DC',
      :zipcode => '20123',
      :phone => '(555)555-5555',
      :state_name => 'MD',
      :country => @country
    )
    @address.save!

    @creditcard = Factory(:creditcard, :verification_value => '123', :number => '4242424242424242', :month => 9, :year => Time.now.year + 1, :first_name => 'John', :last_name => 'Doe')
    @checkout = Factory(:checkout, :creditcard => @creditcard, :bill_address => @address, :ship_address => @address)
    @gateway = Gateway::AuthorizeNetCim.create!(:name => 'Authorize.net CIM Gateway')
    @creditcard.reload
    
    @address_options = { 
      :first_name => 'John',
      :last_name => 'Doe',
      :address1 => '1234 My Street',
      :address2 => 'Apt 1',
      :city     => 'Washington DC',
      :state    => 'MD',
      :zip      => '20123',
      :country  => 'US',
      :phone    => '(555)555-5555'
    }
  end

  context "options_for_create_customer_profile" do
    should "build correct options hash" do
      expected_options = {:profile => { 
        :payment_profiles => {
          :bill_to => @address_options,
          :payment => {:credit_card => @creditcard}
          },
          :ship_to_list => @address_options
        }}

      options = @gateway.send(:options_for_create_customer_profile, @creditcard, @creditcard.gateway_options)
      merchant_customer_id = options[:profile].delete(:merchant_customer_id)

      assert_equal expected_options, options
    end
  end
  
  context "create_customer_profile" do
    should "create a customer profile sucessfully" do
      result = @gateway.send(:create_customer_profile, @creditcard, @creditcard.gateway_options)
      assert result.is_a?(Hash)
      assert_equal "123", result[:customer_profile_id]
    end
    should "raise a gateway error if there is a problem creating profile" do
      ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = true
      assert_raise(Spree::GatewayError) { @gateway.send(:create_customer_profile, @creditcard, @creditcard.gateway_options) }
    end
  end

  context "authorize" do
    setup do
      @response = @gateway.authorize(500, @creditcard, @creditcard.gateway_options)
    end
    should "return successfull Response object" do
      assert @response.is_a?(ActiveMerchant::Billing::Response)
      assert @response.success?
    end
    should "update creditcard with gateway_customer_profile_id and gateway_payment_profile_id" do
      assert_equal "123", @creditcard.gateway_customer_profile_id
      assert_equal "456", @creditcard.gateway_payment_profile_id
    end
    should "have authorization code in response" do
      assert_equal '123456', @response.authorization
    end
  end

end
