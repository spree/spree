require 'spec_helper'

describe 'Create New Promotion', type: :feature, js: true do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let!(:store_2) { create(:store) }

  context 'coupon promotions' do
    before do
      visit spree.new_admin_promotion_path
    end

    it 'Checkbox generates random promotion code' do
      fill_in 'Name', with: 'Promotion 1'
      check 'Generate coupon code'

      click_button 'Create'

      promotion = store.promotions.find_by!(name: 'Promotion 1')
      expect(page).to have_field(id: 'promotion_code', with: promotion.code)
      expect(promotion.stores).to eq([store])
    end

    it 'Allows you to set a promotion with start and end time' do
      fill_in 'Name', with: 'Promotion 2'

      fill_in_date_picker('promotion_starts_at', { year: 2012, month: 1, day: 18, hour: 16, minute: 45 })
      fill_in_date_picker('promotion_expires_at', { year: 2013, month: 3, day: 25, hour: 22, minute: 10 })

      fill_in 'Code', with: 'Random 2323'

      click_button 'Create'

      promotion = store.promotions.last
      expect(promotion.starts_at).to eq(DateTime.new(2012, 1, 18, 16, 45))
      expect(promotion.expires_at).to eq(DateTime.new(2013, 3, 25, 22, 10))
    end

    it 'allows assigning multiple stores' do
      fill_in 'Name', with: 'Promotion 3'
      select2 store_2.unique_name, from: 'Stores'

      click_button 'Create'

      expect(page).to have_content('successfully created')

      promotion = store.promotions.find_by!(name: 'Promotion 3')
      expect(promotion.stores).to contain_exactly(store, store_2)
    end
  end
end
