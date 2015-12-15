require 'spec_helper'

describe 'Free shipping promotions', type: :feature, js: true do
  before { create(:store, default: true) }

  let!(:country)        { create(:country)                 }
  let!(:state)          { create(:state, country: country) }
  let!(:zone)           { create(:zone)                    }
  let!(:address)        { build(:address, state: state)    }
  let!(:payment_method) { create(:check_payment_method)    }
  let!(:product)        { create(:product, price: 20)      }

  let!(:shipping_method) do
    create(
      :shipping_method,
      calculator: Spree::Calculator::FlatRate.new(preferred_amount: 10)
    )
  end

  let!(:promotion) do
    Spree::Promotion::Actions::FreeShipping.create!(
      promotion: build(
        :promotion,
        starts_at:  1.day.ago,
        expires_at: 1.day.from_now
      )
    ).promotion
  end

  context 'free shipping promotion automatically applied' do
    before do
      visit spree.root_path
      click_link product.name
      click_button 'add-to-cart-button'
      click_button 'Checkout'
      fill_in 'order_email', with: 'spree@example.com'
      fill_in_address_form('order_bill_address_attributes', address)

      # To shipping method screen
      click_button 'Save and Continue'
      # To payment screen
      click_button 'Save and Continue'
    end

    # Regression test for #4428
    it 'applies the free shipping promotion' do
      within('#checkout-summary') do
        expect(page).to have_content('Shipping total:  $10.00')
        expect(page).to have_content("Promotion (#{promotion.name}): -$10.00")
      end
    end
  end
end
