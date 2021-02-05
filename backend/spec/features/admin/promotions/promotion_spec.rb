require 'spec_helper'

describe 'Create New Promotion', type: :feature, js: true do
  stub_authorization!

  context 'coupon promotions' do
    before do
      visit spree.new_admin_promotion_path
    end

    it 'Checkbox generates random promotion code' do
      fill_in 'Name', with: 'Promotion 1'
      check 'Generate coupon code'

      click_button 'Create'

      promotion = Spree::Promotion.find_by(name: 'Promotion 1')
      expect(page).to have_field(id: 'promotion_code', with: promotion.code)
    end

    it 'Allows you to set a promotion with start and end time' do
      fill_in 'Name', with: 'Promotion 2'
      fill_in 'Code', with: 'Random 2323'
      fill_in_date_time_picker('promotion_starts_at', with: '2012-01-24-16-45')
      fill_in_date_time_picker('promotion_expires_at', with: '2012-01-25-22-10')

      click_button 'Create'

      expect(page).to have_field(id: 'promotion_starts_at', type: :hidden, with: '2012-01-24 16:45')
      expect(page).to have_field(id: 'promotion_expires_at', type: :hidden, with: '2012-01-25 22:10')
    end
  end
end
