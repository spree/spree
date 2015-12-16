require 'spec_helper'

# Gigantic regression test for #2191
describe 'Free shipping promotions', type: :feature, js: true do
  before { create(:store, default: true) }

  let!(:country)        { create(:country)                 }
  let!(:state)          { create(:state, country: country) }
  let!(:zone)           { create(:zone)                    }
  let!(:payment_method) { create(:check_payment_method)    }
  let!(:product)        { create(:product, price: 20)      }
  let!(:free_product)   { create(:product, price: 20)      }
  let(:address)         { build(:address, state: state)    }

  let!(:shipping_method) do
    create(
      :shipping_method,
      calculator: Spree::Calculator::FlatRate.new(preferred_amount: 10)
    )
  end

  let!(:promotion) do
    promotion = create(
      :promotion,
      starts_at:  1.day.ago,
      expires_at: 1.day.from_now,
      code:       'freeshirt'
    )

    Spree::Promotion::Actions::CreateLineItems.create!(
      promotion: promotion
    ).tap do |action|
      action.promotion_action_line_items.create!(
        variant:  free_product.master,
        quantity: 1
      )
    end

    Spree::Promotion::Actions::CreateAdjustment.create!(
      promotion:  promotion,
      calculator: Spree::Calculator::FlatRate.new(
        preferred_amount: 20
      )
    )

    promotion.reload # so that promotion.actions is available
  end

  context 'promotion with free line item' do
    before do
      visit spree.root_path
      click_link product.name
      click_button 'add-to-cart-button'
      fill_in 'order_coupon_code', with: promotion.code
      click_button 'Update'

      all('a.delete').first.click # Delete the first line item
      expect(page).not_to have_content(product.name)
      expect(page).to have_content(free_product.name)
      expect(page).to have_content("Adjustment: Promotion (#{promotion.name}) -$20.00")
      expect(page).to have_content('Total $0.00')

      click_button 'Checkout'
      fill_in 'order_email', with: 'spree@example.com'
      fill_in_address_form('order_bill_address_attributes', address)

      # To shipping method screen
      click_button 'Save and Continue'
      # To payment screen
      click_button 'Save and Continue'
    end

    # The actual regression test for #2191
    it 'does not skip the payment step' do
      # The bug is that it skips the payment step because the shipment cost has not been set for the order.
      # Therefore we are checking here that it's *definitely* on the payment step and hasn't jumped to complete.
      expect(page).to have_selector('form[action="/checkout/update/payment"]')

      within('#checkout-summary') do
        expect(page).to have_content('Shipping total:  $10.00')
        expect(page).to have_content("Promotion (#{promotion.name}): -$20.00")
        expect(page).to have_content('Order Total: $10.00')
      end
    end
  end
end
