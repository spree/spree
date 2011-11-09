require 'spec_helper'

describe Spree::Gateway::Eway do

  describe "options" do
    
    let (:gateway) { Spree::Gateway::Eway.new }
    
    it "should include :test => true in  when :test_mode is true" do
      gateway.prefers_test_mode = true
      gateway.options[:test].should == true
    end

    it "should not include :test when test_mode is false" do
      gateway.prefers_test_mode = false
      gateway.options[:test].should be_nil
    end
  end
  
  describe "order tests" do
    
    before(:each) do
      Spree::Gateway.update_all :active => false
      @gateway = Spree::Gateway::Eway.create!(:name => "Eway Gateway", :environment => "test", :active => true)
  
      @gateway.set_preference(:login, "87654321" )
      @gateway.set_preference(:test_mode, true )
      @gateway.save!
  
      @country = Factory(:country, :name => "Australia", :iso_name => "AUSTRALIA", :iso3 => "AUS", :iso => "AU", :numcode => 36)
      @state   = Factory(:state, :name => "South Australia", :abbr => "SA", :country => @country)
      @address = Factory(:address,
        :firstname => 'John',
        :lastname => 'Doe',
        :address1 => '1234 My Street',
        :address2 => 'Apt 1',
        :city =>  'Mount Barker',
        :zipcode => '5152',
        :phone => '(08) 5555 5555',
        :state => @state,
        :country => @country
      )
      
      @order = Factory(:order_with_totals, :bill_address => @address, :ship_address => @address)
      @order.state = "payment"
      @order.update!
    end

    describe "purchase" do
      
      before(:all) do
        Spree::Config.set :auto_capture => true
      end
    
      it "should be able to send a test purchase" do
        @order.update_attributes(
          {
            :payments_attributes => [
              :payment_method_id => @gateway.id,
              :amount => 10,
              :source_attributes => {
                :number => 4444333322221111,
                :verification_value => '123',
                :month => 9,
                :year => Time.now.year + 1,
                :first_name => 'John',
                :last_name => 'Doe'
              }
            ]
          }
        )

        @gateway.options[:test].should == true
        @order.update!
        @order.next!
        @order.state.should == 'complete'
      end
    end
  end
end
