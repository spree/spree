require 'spec_helper'

describe "Checkout" do
  context "visitor makes checkout as guest without registration" do
    context "when backordering is disabled" do
      before(:each) do
        @configuration ||= AppConfiguration.find_or_create_by_name("Default configuration")
        Spree::Config.set :allow_backorders => false
        Product.delete_all
        @product = Factory(:product, :name => "RoR Mug")
        @product.on_hand = 1
        @product.save
        Factory(:zone)
      end

      it "should warn the user about out of stock items" do
        pending "figure out why product on_hand isn't taking effect"

        visit root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"

        @product.on_hand = 0
        @product.save

        click_link "Checkout"
        save_and_open_page

        within(:css, "span.out-of-stock") { page.should have_content("Out of Stock") }
      end
    end
  end
end
