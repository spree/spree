require 'spec_helper'

describe "Payment Methods" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
  end

  context "admin visiting payment methods listing page" do
    it "should display existing payment methods" do
      2.times { create(:payment_method) }
      click_link "Payment Methods"

      find('table#listing_payment_methods th:nth-child(1)').text.should == "Name"
      find('table#listing_payment_methods th:nth-child(2)').text.should == "Provider"
      find('table#listing_payment_methods th:nth-child(3)').text.should == "Environment"
      find('table#listing_payment_methods th:nth-child(4)').text.should == "Display"
      find('table#listing_payment_methods th:nth-child(5)').text.should == "Active"

      # Ensure that it displays the two payment methods we have created
      within('table#listing_payment_methods') do
        page.should have_content("Spree::PaymentMethod::Check")
      end
    end
  end

  context "admin creating a new payment method" do
    it "should be able to create a new payment method" do
      click_link "Payment Methods"
      click_link "admin_new_payment_methods_link"
      page.should have_content("New Payment Method")
      fill_in "payment_method_name", :with => "check90"
      fill_in "payment_method_description", :with => "check90 desc"
      select "PaymentMethod::Check", :from => "gtwy-type"
      click_button "Create"
      page.should have_content("successfully created!")
    end
  end

  context "admin editing a payment method" do
    before(:each) do
      2.times { create(:payment_method) }
      click_link "Payment Methods"
      within(:css, 'table#listing_payment_methods tbody:nth-child(2) tr:nth-child(1)') { click_link "Edit" }
    end

    it "should be able to edit an existing payment method" do
      fill_in "payment_method_name", :with => "Payment 99"
      click_button "Update"
      page.should have_content("successfully updated!")
      find_field("payment_method_name").value.should == "Payment 99"
    end

    it "should display validation errors" do
      fill_in "payment_method_name", :with => ""
      click_button "Update"
      #page.should have_content("Name can't be blank")
    end
  end
end
