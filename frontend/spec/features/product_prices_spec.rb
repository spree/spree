require 'spec_helper'

describe 'Product with prices in multiple currencies', type: :feature, js: true do
  context 'currency switcher' do
    context 'with USD, EUR and GBP as currencies' do
      let!(:store) { create(:store, default: true, supported_currencies: 'USD,EUR,GBP') }
      let!(:product) { create(:product) }

      before do
        create(:price, variant: product.master, currency: 'EUR', amount: 16.00)
        create(:price, variant: product.master, currency: 'GBP', amount: 23.00)
      end

      it 'can switch by currency', :js do
        visit spree.product_path(product)
        expect(page).to have_text '$19.99'
        switch_to_currency('EUR')
        expect(page).to have_text '€16.00'
        expect(page).to have_current_path(spree.product_path(product, currency: 'EUR'))
        switch_to_currency('GBP')
        expect(page).to have_text '£23.00'
        expect(page).to have_current_path(spree.product_path(product, currency: 'GBP'))
        visit spree.products_path
        expect(page).to have_text '£23.00'
        expect(page).to have_link product.name, href: "/products/#{product.slug}?currency=GBP"
        open_i18n_menu
        expect(page).to have_select('switch_to_currency', selected: '£ GBP')
      end
    end
  end

  context 'store default currency' do
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
