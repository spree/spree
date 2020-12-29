require 'spec_helper'

describe 'Free shipping promotions', type: :feature, js: true do
  let!(:country) { create(:country, name: 'United States of America', states_required: true) }
  let!(:state) { create(:state, name: 'Alabama', country: country) }

  before do
    create(:zone)
    sm = create(:shipping_method)
    sm.calculator.preferred_amount = 10
    sm.calculator.save

    create(:check_payment_method)

    action = Spree::Promotion::Actions::FreeShipping.new
    action.promotion = promotion
    action.save

    promotion.reload # so that promotion.actions is available
  end

  context 'free shipping promotion automatically applied' do
    let!(:mug) { create(:product, name: 'RoR Mug', price: 20) }
    let(:promotion) do
      create(:promotion,
             name: 'Free Shipping',
             starts_at: 1.day.ago,
             expires_at: 1.day.from_now)
    end

    include_context 'proceed to payment step'

    # Regression test for #4428
    it 'applies the free shipping promotion' do
      within('#checkout-summary') do
        page.has_text? 'SHIPPING: $10.00'
        page.has_text? 'Promotion (Free Shipping): -$10.00'
      end
    end
  end

  context 'when free shipping promotion applies for order total in defined range' do
    let(:promotion) do
      create(:free_shipping_promotion_with_item_total_rule,
             name: 'Free Shipping',
             starts_at: 1.day.ago,
             expires_at: 1.day.from_now)
    end

    include_context 'proceed to payment step'

    context 'when order total is less than defined range' do
      let!(:mug) { create(:product, name: 'RoR Mug', price: 5) }

      it 'does not apply the free shipping promotion' do
        page.has_text? 'SHIPPING: $10.00'
        page.has_text? 'Promotion (Free Shipping): -$10.00'
      end
    end

    context 'when order total is greater than defined range' do
      let!(:mug) { create(:product, name: 'RoR Mug', price: 60) }

      it 'applies the free shipping promotion' do
        page.has_text? 'SHIPPING: FREE'
      end
    end
  end
end
