require 'spec_helper'

describe "Checkout" do
  context "visitor makes checkout as guest without registration" do
    
    context "when backordering is disabled" do
      before(:each) do
        reset_spree_preferences do |config|
          config.allow_backorders = false
        end
        Spree::Product.delete_all
        @product = Factory(:product, :name => "RoR Mug")
        @product.on_hand = 1
        @product.save
        Factory(:zone)
      end

      it "should warn the user about out of stock items" do
        pending "Failing when run in tandem with spec/requests/admin/orders/customer_details_spec.rb. Recommended to fix that one first."
        visit spree.root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"

        @product.on_hand = 0
        @product.save

        click_link "Checkout"

        within(:css, "span.out-of-stock") { page.should have_content("Out of Stock") }
      end
    end
    
    it "should not autofill the billing address" do
      product = Factory(:product, :name => "RoR Mug")
      visit spree.root_path
      click_link "RoR Mug"
      click_button "add-to-cart-button"
      click_link "Checkout"
      
      fill_in "order_email",  :with => "john.doe@example.com"
      click_button "Continue"
      
      find_field("order_bill_address_attributes_firstname").value.should be_nil
      find_field("order_bill_address_attributes_lastname").value.should be_nil
      find_field("order_bill_address_attributes_address1").value.should be_nil
      find_field("order_bill_address_attributes_address2").value.should be_nil
      find_field("order_bill_address_attributes_city").value.should be_nil
      find_field("order_bill_address_attributes_zipcode").value.should be_nil
      find_field("order_bill_address_attributes_country_id").find('option[selected]').text.should == Spree::Address.default.country.name
      find_field("order_bill_address_attributes_phone").value.should be_nil
    
    end
    
  end
  
  context "visitor makes checkout as logged in user" do
    before(:each) do
      @last_order = Factory(:complete_order)
      Factory(:product, :name => "RoR Mug")
    end
    
    it "should auto fill the billing address with the previous used one" do
      sign_in_as!(@last_order.user)
      visit spree.root_path
      click_link "RoR Mug"
      click_button "add-to-cart-button"
      click_link "Checkout"
      
      find_field("order_bill_address_attributes_firstname").value.should == @last_order.bill_address.firstname
      find_field("order_bill_address_attributes_lastname").value.should == @last_order.bill_address.lastname
      find_field("order_bill_address_attributes_address1").value.should == @last_order.bill_address.address1
      find_field("order_bill_address_attributes_address2").value.should == @last_order.bill_address.address2
      find_field("order_bill_address_attributes_city").value.should == @last_order.bill_address.city
      find_field("order_bill_address_attributes_zipcode").value.should == @last_order.bill_address.zipcode
      find_field("order_bill_address_attributes_country_id").find('option[selected]').text.should == @last_order.bill_address.country.name
      find_field("order_bill_address_attributes_phone").value.should == @last_order.bill_address.phone
      
    end
    
    it "should not auto fill the billing address when there is no previous order" do
      sign_in_as!(Factory(:user))
      visit spree.root_path
      click_link "RoR Mug"
      click_button "add-to-cart-button"
      click_link "Checkout"
      
      find_field("order_bill_address_attributes_firstname").value.should be_nil
      find_field("order_bill_address_attributes_lastname").value.should be_nil
      find_field("order_bill_address_attributes_address1").value.should be_nil
      find_field("order_bill_address_attributes_address2").value.should be_nil
      find_field("order_bill_address_attributes_city").value.should be_nil
      find_field("order_bill_address_attributes_zipcode").value.should be_nil
      find_field("order_bill_address_attributes_country_id").find('option[selected]').text.should == Spree::Address.default.country.name
      find_field("order_bill_address_attributes_phone").value.should be_nil
      
    end
    
  end

end
