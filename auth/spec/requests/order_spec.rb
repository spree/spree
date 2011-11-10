require 'spec_helper'

describe "Orders" do
  it "should allow a user to view their cart at any time" do
    visit spree_core.cart_path
    page.should have_content("Your cart is empty")
  end
end
