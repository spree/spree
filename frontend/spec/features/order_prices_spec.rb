require 'spec_helper'

describe 'Order', type: :feature, js: true do
  let!(:product) { create(:product) }

  before do
    reset_spree_preferences do |config|
      config.supported_currencies   = 'USD,EUR,GBP'
      config.allow_currency_change  = true
      config.show_currency_selector = true
    end
    create(:price, variant: product.master, currency: 'EUR', amount: 16.00)
    create(:price, variant: product.master, currency: 'GBP', amount: 23.00)
  end

  context 'when existing in the cart' do
    it 'changes its currency, if user switches the currency.' do
      visit spree.product_path(product)
      click_button 'Add To Cart'
      expect(page).to have_text '$19.99'
      select 'EUR', from: 'currency'
      expect(page).to have_text '€16.00'
    end
  end
end
