require 'spec_helper'

describe 'Product with prices in multiple currencies', type: :feature, js: true do
  context 'with USD, EUR and GBP as currencies' do
    let!(:store) { create(:store, default: true) }
    let!(:product) { create(:product) }

    before do
      reset_spree_preferences do |config|
        config.allow_currency_change  = true
        config.show_currency_selector = true
      end
      create(:price, variant: product.master, currency: 'EUR', amount: 16.00)
      create(:price, variant: product.master, currency: 'GBP', amount: 23.00)
    end

    it 'can switch by currency', :js do
      visit spree.product_path(product)
      expect(page).to have_text '$19.99'
      select 'EUR', from: 'currency'
      expect(page).to have_text '€16.00'
      select 'GBP', from: 'currency'
      expect(page).to have_text '£23.00'
    end

    context 'and :show_currency_selector is false' do
      before do
        reset_spree_preferences do |config|
          config.allow_currency_change  = true
          config.show_currency_selector = false
        end
      end

      it 'will not render the currency selector' do
        visit spree.product_path(product)
        expect(page).to have_current_path(spree.product_path(product))
        expect(page).to_not have_text 'Currency'
      end
    end

    context 'and :allow_currency_change is false' do
      context 'and show_currency_selector is true' do
        before do
          reset_spree_preferences do |config|
            config.allow_currency_change  = false
            config.show_currency_selector = true
          end
        end

        it 'will not render the currency selector' do
          visit spree.product_path(product)
          expect(page).to have_current_path(spree.product_path(product))
          expect(page).to_not have_text 'Currency'
        end
      end
    end
  end
end
