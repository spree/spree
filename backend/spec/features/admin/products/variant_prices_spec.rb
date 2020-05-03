require 'spec_helper'

describe 'Variant Prices', type: :feature, js: true do
  stub_authorization!
  let!(:store) { create(:store, default: true, supported_currencies: 'USD,EUR') }
  let!(:store2) { create(:store, default: false, default_currency: 'GBP') }
  let!(:product) { create(:product) }

  context 'with USD and EUR as currencies' do
    it 'allows to save a price for each currency' do
      visit spree.admin_product_path(product)
      click_link 'Prices'
      expect(page).to have_content 'USD'
      expect(page).to have_content 'EUR'
      expect(page).to have_content 'GBP'

      fill_in "vp_#{product.master.id}_USD", with: '29.95'
      fill_in "vp_#{product.master.id}_EUR", with: '21.94'
      fill_in "vp_#{product.master.id}_GBP", with: '19.94'

      click_button 'Update'
      expect(page).to have_content 'Prices successfully saved'
      expect(product.master.price_in('USD').amount).to eq(29.95)
      expect(product.master.price_in('EUR').amount).to eq(21.94)
      expect(product.master.price_in('GBP').amount).to eq(19.94)
    end
  end
end
