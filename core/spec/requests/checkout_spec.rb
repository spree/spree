require 'spec_helper'

describe "Checkout" do
  context "visitor makes checkout as guest without registration" do
    context "when backordering is disabled" do
      before(:each) do
        reset_spree_preferences do |config|
          config.allow_backorders = false
        end
        Spree::Product.delete_all
        @product = Factory(:product, :name => "RoR Mug")
        @product.on_hand = 1
        @product.save
        Factory(:zone)
      end

      it "should warn the user about out of stock items" do
        pending "Failing when run in tandem with spec/requests/admin/orders/customer_details_spec.rb. Recommended to fix that one first."
        visit spree.root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"

        @product.on_hand = 0
        @product.save

        click_link "Checkout"

        within(:css, "span.out-of-stock") { page.should have_content("Out of Stock") }
      end
    end
  end
end
