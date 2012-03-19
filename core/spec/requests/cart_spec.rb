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
end
