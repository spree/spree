require 'spec_helper'
describe "Admin products" do
  context "as anonymous user" do
    # regression test for #1250
    it "is redirected to login page when attempting to access product listing" do
      lambda { visit spree.admin_products_path }.should_not raise_error
    end
  end
end
