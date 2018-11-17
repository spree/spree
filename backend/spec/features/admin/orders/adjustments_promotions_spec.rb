require 'spec_helper'

describe 'Adjustments Promotions', type: :feature do
  stub_authorization!

  before do
    create(:promotion_with_item_adjustment,
           name: '$10 off',
           path: 'test',
           code: '10_off',
           starts_at: 1.day.ago,
           expires_at: 1.day.from_now,
           adjustment_rate: 10)

    order = create(:order_with_totals)
    line_item = order.line_items.first
    # so we can be sure of a determinate price in our assertions
    line_item.update_column(:price, 10)

    visit spree.admin_order_adjustments_path(order)
  end

  context 'admin adding a promotion' do
    context 'successfully' do
      it 'creates a new adjustment', js: true do
        fill_in 'coupon_code', with: '10_off'
        click_button 'Add Coupon Code'
        expect(page).to have_content('$10 off')
        expect(page).to have_content('-$10.00')
      end
    end

    context 'for non-existing promotion' do
      it 'shows an error message', js: true do
        fill_in 'coupon_code', with: 'does_not_exist'
        click_button 'Add Coupon Code'
        expect(page).to have_content("doesn't exist.")
      end
    end

    context 'for already applied promotion' do
      it 'shows an error message', js: true do
        fill_in 'coupon_code', with: '10_off'
        click_button 'Add Coupon Code'
        expect(page).to have_content('-$10.00')

        fill_in 'coupon_code', with: '10_off'
        click_button 'Add Coupon Code'
        expect(page).to have_content('already been applied')
      end
    end
  end
end
