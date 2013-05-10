require 'spec_helper'

describe "Shipping Methods" do
  stub_authorization!
  let!(:zone) { create(:global_zone) }
  let!(:shipping_method) { create(:shipping_method, :zones => [zone]) }

  after do
    Capybara.ignore_hidden_elements = true
  end

  before do
    Capybara.ignore_hidden_elements = false
    # HACK: To work around no email prompting on check out
    Spree::Order.any_instance.stub(:require_email => false)
    create(:payment_method, :environment => 'test')

    visit spree.admin_path
    click_link "Configuration"
    click_link "Shipping Methods"
  end

  context "show" do
    it "should display existing shipping methods" do
      within_row(1) do
        column_text(1).should == shipping_method.name 
        column_text(2).should == zone.name
        column_text(3).should == "Flat Rate (per order)"
        column_text(4).should == "Both"
      end
    end
  end

  context "create" do
    it "should be able to create a new shipping method" do
      click_link "New Shipping Method"

      fill_in "shipping_method_name", :with => "bullock cart"

      within("#shipping_method_categories_field") do
        check first("input[type='checkbox']")["name"]
      end

      click_on "Create"
      expect(current_path).to eql(spree.edit_admin_shipping_method_path(Spree::ShippingMethod.last))
    end
  end

  # Regression test for #1331
  context "update" do
    it "can change the calculator", :js => true do
      within("#listing_shipping_methods") do
        click_icon :edit
      end

      find(:css, ".calculator-settings-warning").should_not be_visible
      select2_search('Flexible Rate', :from => 'Calculator')
      find(:css, ".calculator-settings-warning").should be_visible

      click_button "Update"
      page.should_not have_content("Shipping method is not found")
    end
  end
end
