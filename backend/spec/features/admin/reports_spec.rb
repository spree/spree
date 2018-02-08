require 'spec_helper'

describe 'Reports', type: :feature do
  stub_authorization!

  context 'visiting the admin reports page' do
    it 'has the right content' do
      visit spree.admin_path
      click_link 'Reports'
      click_link 'Sales Total'

      expect(page).to have_content('Sales Totals')
      expect(page).to have_content('Item Total')
      expect(page).to have_content('Adjustment Total')
      expect(page).to have_content('Sales Total')
    end
  end

  context 'searching the admin reports page' do
    before do
      order = create(:order)
      order.update_columns(adjustment_total: 100)
      order.completed_at = Time.current
      order.save!

      order = create(:order)
      order.update_columns(adjustment_total: 200)
      order.completed_at = Time.current
      order.save!

      # incomplete order
      order = create(:order)
      order.update_columns(adjustment_total: 50)
      order.save!

      order = create(:order)
      order.update_columns(adjustment_total: 200)
      order.completed_at = 3.years.ago
      order.created_at = 3.years.ago
      order.save!

      order = create(:order)
      order.update_columns(adjustment_total: 200)
      order.completed_at = 3.years.from_now
      order.created_at = 3.years.from_now
      order.save!
    end

    it 'allows me to search for reports' do
      visit spree.admin_path
      click_link 'Reports'
      click_link 'Sales Total'

      fill_in 'q_completed_at_gt', with: 1.week.ago
      fill_in 'q_completed_at_lt', with: 1.week.from_now
      click_button 'Search'

      expect(page).to have_content('$300.00')
    end
  end
end
