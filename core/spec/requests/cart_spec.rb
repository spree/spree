require 'spec_helper'

describe "Cart" do
  it "shows cart icon on non-cart pages" do
    visit spree.root_path
    lambda { find("li#link-to-cart a") }.should_not raise_error(Capybara::ElementNotFound)
  end

  it "hides cart icon on cart page" do
    visit spree.cart_path
    lambda { find("li#link-to-cart a") }.should raise_error(Capybara::ElementNotFound)
  end

  it "prevents double clicking the remove button on cart", :js => true do
    @product = create(:product, :name => "RoR Mug")
    @product.on_hand = 1
    @product.save

    visit spree.root_path
    click_link "RoR Mug"
    click_button "add-to-cart-button"

    # prevent form submit to verify button is disabled
    page.execute_script("$('#update-cart').submit(function(){return false;})")

    page.should_not have_selector('button#update-button[disabled]')
    page.find(:css, '.delete img').click
    page.should have_selector('button#update-button[disabled]')
  end
end
