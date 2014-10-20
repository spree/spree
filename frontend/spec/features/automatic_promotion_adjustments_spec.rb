require 'spec_helper'

describe "Automatic promotions", :type => :feature, :js => true do
  let!(:country) { create(:country, :name => "United States of America", :states_required => true) }
  let!(:state) { create(:state, :name => "Alabama", :country => country) }
  let!(:zone) { create(:zone) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:payment_method) { create(:check_payment_method) }
  let!(:product) { create(:product, :name => "RoR Mug", :price => 20) }

  let!(:promotion) do
    promotion = Spree::Promotion.create!(:name => "$10 off when you spend more than $100")

   calculator = Spree::Calculator::FlatRate.new
   calculator.preferred_amount = 10

   rule = Spree::Promotion::Rules::ItemTotal.create
   rule.preferred_amount_min = 100
   rule.save

   promotion.rules << rule

   action = Spree::Promotion::Actions::CreateAdjustment.create
   action.calculator = calculator
   action.save

   promotion.actions << action
  end

  context "on the cart page" do

    before do
      visit spree.root_path
      click_link product.name
      click_button "add-to-cart-button"
    end

    it "automatically applies the promotion once the order crosses the threshold" do
      fill_in "order_line_items_attributes_0_quantity", :with => 10
      click_button "Update"
      expect(page).to have_content("Promotion ($10 off when you spend more than $100) -$10.00")
      fill_in "order_line_items_attributes_0_quantity", :with => 1
      click_button "Update"
      expect(page).not_to have_content("Promotion ($10 off when you spend more than $100) -$10.00")
    end
  end
end
