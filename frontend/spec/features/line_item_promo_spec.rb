require 'spec_helper'

describe 'Line items promotions', type: :feature, js: true do
  let!(:country) { create(:country, name: 'United States of America', states_required: true) }
  let!(:state) { create(:state, name: 'Alabama', country: country) }
  let!(:mug) { create(:product, name: 'RoR Mug', price: 20) }
  let!(:shirt) { create(:product, name: 'RoR Shirt', price: 66) }

  before do
    create(:zone)
    create(:shipping_method)
    create(:check_payment_method)
    create(:store)
  end

  context 'User on cart' do
    def create_line_item_action_promotion
      promotion = Spree::Promotion.create!(name: 'Add free item',
                                           code: 'free_item',
                                           starts_at: 1.day.ago,
                                           expires_at: 1.day.from_now)

      action = Spree::Promotion::Actions::CreateLineItems.new
      action.promotion = promotion

      action_line_item = Spree::PromotionActionLineItem.create!(
        promotion_action: action,
        variant: shirt.master,
        quantity: 1
      )

      action.promotion_action_line_items << action_line_item
      action.save

      promotion.reload # so that promotion.actions is available
    end

    let!(:promotion) { create_line_item_action_promotion }

    def apply_coupon(code)
      fill_in 'order_coupon_code', with: code
      click_button 'shopping-cart-coupon-code-button'
    end

    it 'adds free product with promo code' do
      add_to_cart(mug)
      apply_coupon('free_item')

      expect(page).to have_content(shirt.name)
    end

    it 'removes free product added with promo code' do
      add_to_cart(mug)
      apply_coupon('free_item')

      line_item = Spree::Order.last.line_items.last
      within('#line_items') do
        click_link "delete_line_item_#{line_item.id}"
      end

      expect(page).not_to have_content(shirt.name)
    end
  end
end
