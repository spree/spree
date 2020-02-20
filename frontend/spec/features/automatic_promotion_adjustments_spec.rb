require 'spec_helper'

describe 'Automatic promotions', type: :feature, js: true do
  let!(:country) { create(:country, name: 'United States of America', states_required: true) }
  let!(:product) { create(:product, name: 'RoR Mug', price: 20) }

  before do
    create(:state, name: 'Alabama', country: country)
    create(:zone)
    create(:shipping_method)
    create(:check_payment_method)

    promotion = Spree::Promotion.create!(name: '$10 off when you spend more than $100')

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

  context 'on the cart page' do
    before do
      add_to_cart(product)
    end

    it 'automatically applies the promotion once the order crosses the threshold' do
      fill_in 'order_line_items_attributes_0_quantity', with: 10
      # this is needed to reset a mouse focus (so quantity will update)
      find('.shopping-cart-header').click

      click_link 'checkout'
      expect(page).to have_content('PROMOTION ($10 OFF WHEN YOU SPEND MORE THAN $100)')

      visit '/cart'

      fill_in 'order_line_items_attributes_0_quantity', with: 1
      find('.shopping-cart-header').click

      click_link 'checkout'

      expect(page).not_to have_content('PROMOTION ($10 OFF WHEN YOU SPEND MORE THAN $100)')
    end
  end
end
