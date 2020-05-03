require 'spec_helper'

describe 'Product with prices in multiple currencies', type: :feature, js: true do
  xcontext 'currency switcher' do
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

  context 'store currency' do
    let!(:store) { create(:store, default: true, default_currency: 'GBP') }
    let(:product) { create(:product, price: 9.99, currency: 'USD') }

    context 'product with price in GBP' do
      before do
        create(:price, variant: product.master, amount: 8.99, currency: 'GBP')
      end

      it 'renders the GBP price' do
        visit spree.product_path(product)
        expect(page).to have_content('£8.99')
      end

      it 'can add product to a cart' do
        add_to_cart(product)
        expect(page).to have_content('£8.99')
      end
    end

    context 'product withouth a price in GBP' do
      before do
        visit spree.product_path(product)
      end

      it 'doesnt render price' do
        expect(page).not_to have_content('£8.99')
        expect(page).not_to have_content('9.99$')
      end

      it 'doesnt render add to cart button' do
        expect(page).not_to have_content('Add To Cart')
        expect(page).to have_content('THIS PRODUCT IS NOT AVAILABLE IN THE SELECTED CURRENCY')
      end
    end
  end
end
