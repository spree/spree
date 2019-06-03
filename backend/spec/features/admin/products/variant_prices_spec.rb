require 'spec_helper'

describe 'Variant Prices', type: :feature, js: true do
  stub_authorization!

  let!(:product) { create(:product) }

  context 'with USD and EUR as currencies' do
    before do
      reset_spree_preferences do |config|
        config.supported_currencies = 'USD,EUR'
<<<<<<< HEAD
        config.allow_currency_change = true
=======
>>>>>>> 4eadff5c14... Adds spree_multi_currency logic to spree 4.0
      end
    end

    it 'allows to save a price for each currency' do
      visit spree.admin_product_path(product)
      click_link 'Prices'
      expect(page).to have_content 'USD'
      expect(page).to have_content 'EUR'

      fill_in "vp_#{product.master.id}_USD", with: '29.95'
      fill_in "vp_#{product.master.id}_EUR", with: '21.94'

      click_button 'Update'
      expect(page).to have_content 'Prices successfully saved'
    end
  end
end
