require 'spec_helper'

describe 'page promotions', type: :feature, js: true do
  let(:mug) { create(:product, name: 'RoR Mug', price: 20) }

  before do
    promotion = Spree::Promotion.create!(name: '$10 off',
                                         path: 'test',
                                         starts_at: 1.day.ago,
                                         expires_at: 1.day.from_now)

    calculator = Spree::Calculator::FlatRate.new
    calculator.preferred_amount = 10

    action = Spree::Promotion::Actions::CreateAdjustment.create(calculator: calculator)
    promotion.actions << action

    add_to_cart(mug)
  end

  it 'automatically applies a page promotion upon visiting' do
    expect(page).not_to have_field('order_applied_coupon_code', with: 'PROMOTION ($10 OFF)')
    visit '/content/test'
    visit '/checkout'
    expect(page).to have_content('PROMOTION ($10 OFF)')
  end

  it "does not activate an adjustment for a path that doesn't have a promotion" do
    expect(page).not_to have_field('order_applied_coupon_code', with: 'PROMOTION ($10 OFF)')
    visit '/content/cvv'
    visit '/checkout'
    expect(page).not_to have_content('PROMOTION ($10 OFF)')
  end
end
