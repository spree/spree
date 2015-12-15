require 'spec_helper'

describe "Free shipping promotions", :type => :feature, :js => true do
  before { create(:store, default: true) }

  let!(:country)        { create(:country)                 }
  let!(:state)          { create(:state, country: country) }
  let!(:zone)           { create(:zone)                    }
  let!(:address)        { build(:address, state: state)    }
  let!(:payment_method) { create(:check_payment_method)    }
  let!(:product)        { create(:product, price: 20)      }

  let!(:shipping_method) do
    sm = create(:shipping_method)
    sm.calculator.preferred_amount = 10
    sm.calculator.save!
    sm
  end

  let!(:payment_method) { create(:check_payment_method) }
  let!(:product) { create(:product, :name => "RoR Mug", :price => 20) }
  let!(:promotion) do
    promotion = Spree::Promotion.create!(:name       => "Free Shipping",
                                         :starts_at  => 1.day.ago,
                                         :expires_at => 1.day.from_now)

    action = Spree::Promotion::Actions::FreeShipping.new
    action.promotion = promotion
    action.save!

    promotion.reload # so that promotion.actions is available
  end

  context "free shipping promotion automatically applied" do
    before do

      visit spree.root_path
      click_link product.name
      click_button 'add-to-cart-button'
      click_button 'Checkout'
      fill_in 'order_email', with: 'spree@example.com'
      fill_in_address_form('order_bill_address_attributes', address)

      # To shipping method screen
      click_button "Save and Continue"
      # To payment screen
      click_button "Save and Continue"
    end

    # Regression test for #4428
    it "applies the free shipping promotion" do
      within("#checkout-summary") do
        expect(page).to have_content("Shipping total:  $10.00")
        expect(page).to have_content("Promotion (Free Shipping): -$10.00")
      end
    end
  end
end
