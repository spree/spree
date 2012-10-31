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
    @product = create(:product, :name => "RoR Mug", :on_hand => 1)

    visit spree.root_path
    click_link "RoR Mug"
    click_button "add-to-cart-button"

    # prevent form submit to verify button is disabled
    page.execute_script("$('#update-cart').submit(function(){return false;})")

    page.should_not have_selector('button#update-button[disabled]')
    page.find(:css, '.delete img').click
    page.should have_selector('button#update-button[disabled]')
  end

  # Regression test for #2006
  it "does not error out with a 404 when GET'ing to /orders/populate" do
    visit '/orders/populate'
    within(".error") do
      page.should have_content(I18n.t(:populate_get_error))
    end
  end

  it 'allows you to remove an item from the cart', :js => true do
    create(:product, :name => "RoR Mug", :on_hand => 1)
    visit spree.root_path
    click_link "RoR Mug"
    click_button "add-to-cart-button"
    within("#line_items") do
      click_link "delete_line_item_1"
    end
    page.should_not have_content("Line items quantity must be an integer")
  end
end
