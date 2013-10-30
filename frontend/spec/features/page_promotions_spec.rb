require 'spec_helper'

describe 'page promotions' do
  let!(:product) { create(:product, :name => "RoR Mug", :price => 20) }
  before do
    promotion = Spree::Promotion.create!(:name       => "$10 off",
                                         :path       => 'test',
                                         :starts_at  => 1.day.ago,
                                         :expires_at => 1.day.from_now)

   calculator = Spree::Calculator::FlatRate.new
   calculator.preferred_amount = 10

   action = Spree::Promotion::Actions::CreateItemAdjustments.create(:calculator => calculator)
   promotion.actions << action

   visit spree.root_path
   click_link "RoR Mug"
   click_button "add-to-cart-button"
  end

  it "automatically applies a page promotion upon visiting" do
    page.should_not have_content("Promotion ($10 off) -$10.00")
    visit '/content/test'
    visit '/cart'
    page.should have_content("Promotion ($10 off) -$10.00")
    page.should have_content("Subtotal: $10.00")
  end

  it "does not activate an adjustment for a path that doesn't have a promotion" do
    page.should_not have_content("Promotion ($10 off) -$10.00")
    visit '/content/cvv'
    visit '/cart'
    page.should_not have_content("Promotion ($10 off) -$10.00")
  end
end