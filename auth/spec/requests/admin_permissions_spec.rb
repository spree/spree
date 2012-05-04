require 'spec_helper'

describe "Admin Permissions" do
  context "admin is restricted from accessing orders" do
    before(:each) do
      user = create(:admin_user, :email => "admin@person.com", :password => "password", :password_confirmation => "password")
      Spree::Ability.register_ability(AbilityDecorator)
      visit spree.login_path
      fill_in "user_email", :with => user.email
      fill_in "user_password", :with => user.password
      click_button "Login"
    end

    it "should not be able to list orders" do
      visit spree.admin_orders_path
      page.should have_content("Authorization Failure")
    end

    it "should not be able to edit orders" do
      create(:order, :number => "R123")
      visit spree.edit_admin_order_path("R123")
      page.should have_content("Authorization Failure")
    end

    it "should not be able to view an order" do
      create(:order, :number => "R123")
      visit spree.admin_order_path("R123")
      page.should have_content("Authorization Failure")
    end
  end
end
