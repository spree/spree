require 'spec_helper'

describe "Orders" do
  it "should allow a user to view their cart at any time" do
    visit spree.cart_path
    page.should have_content("Your cart is empty")
  end
  
  # regression test for #1687
  it "should merge incomplete orders from different sessions" do
    create(:product, :name => "RoR Mug")
    create(:product, :name => "RoR Shirt")
    
    user = create(:user, :email => "email@person.com", :password => "password", :password_confirmation => "password")

    using_session("first") do
      visit spree.root_path

      click_link "RoR Mug"
      click_button "Add To Cart"

      visit spree.login_path
      fill_in "user_email", :with => user.email
      fill_in "user_password", :with => user.password
      click_button "Login"

      click_link "Cart"
      page.should have_content("RoR Mug")
    end
    
    using_session("second") do
      visit spree.root_path

      click_link "RoR Shirt"
      click_button "Add To Cart"

      visit spree.login_path
      fill_in "user_email", :with => user.email
      fill_in "user_password", :with => user.password
      click_button "Login"
      
      # order should have been merged with first session
      click_link "Cart"
      page.should have_content("RoR Mug")
      page.should have_content("RoR Shirt")
    end
    
    using_session("first") do
      visit spree.root_path
      
      click_link "Cart"
      
      # order should have been merged with second session
      page.should have_content("RoR Mug")
      page.should have_content("RoR Shirt")
    end
  end

end
