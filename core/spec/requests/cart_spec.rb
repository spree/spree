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

  # Regression test for #2006
  it "does not error out with a 404 when GET'ing to /orders/populate" do
    visit '/orders/populate'
    within(".error") do
      page.should have_content(I18n.t(:populate_get_error))
    end
  end
end
