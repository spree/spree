require 'spec_helper'

describe 'page promotions', type: :feature do
  before { create(:store, default: true) }

  let!(:product) { create(:product, price: 20) }

  let!(:promotion) do
    create(
      :promotion,
      path:       'test',
      starts_at:  1.day.ago,
      expires_at: 1.day.from_now
    )
  end

  before do
    promotion.actions << Spree::Promotion::Actions::CreateItemAdjustments
      .create!(
        calculator: Spree::Calculator::FlatRate.new(preferred_amount: 10)
      )

    visit spree.root_path
    click_link product.name
    click_button 'add-to-cart-button'
  end

  it 'automatically applies a page promotion upon visiting' do
    expect(page).to_not have_content("Promotion (#{promotion.name}) -$10.00")
    visit '/content/test'
    visit '/cart'
    expect(page).to have_content("Promotion (#{promotion.name}) -$10.00")
    expect(page).to have_content('Subtotal (1 item) $20.00')
  end

  it "does not activate an adjustment for a path that doesn't have a promotion" do
    expect(page).to_not have_content("Promotion (#{promotion.name}) -$10.00")
    visit '/content/cvv'
    visit '/cart'
    expect(page).to_not have_content("Promotion (#{promotion.name}) -$10.00")
  end
end
