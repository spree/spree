require 'spec_helper'

describe 'Variants', type: :feature do
  stub_authorization!

  let(:product) { create(:product_with_option_types, price: '1.99', cost_price: '1.00', weight: '2.5', height: '3.0', width: '1.0', depth: '1.5') }

  context 'creating a new variant' do
    it 'allows an admin to create a new variant', js: true do
      product.options.each do |option|
        create(:option_value, option_type: option.option_type)
      end

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }
      click_link 'Variants'
      click_on 'Add One'
      expect(page).to have_field(id: 'variant_price', with: '1.99')
      expect(page).to have_field(id: 'variant_cost_price', with: '1.00')
      expect(page).to have_field(id: 'variant_weight', with: '2.50')
      expect(page).to have_field(id: 'variant_height', with: '3.00')
      expect(page).to have_field(id: 'variant_width', with: '1.00')
      expect(page).to have_field(id: 'variant_depth', with: '1.50')
      expect(page).to have_css('.form-group[data-hook="tax_category"]', text: 'None')
    end
  end

  context 'listing variants' do
    context "there's fewer than 26 variants" do
      it 'displays pagination' do
        visit spree.admin_product_variants_path(product)
        expect(product.variants.size < 26).to be_truthy
        expect(page).not_to have_css('.pagination.d-inline-flex')
        expect(page).to have_css('select[name="per_page"]')
      end
    end

    context "there's variants than in preference variants_per_page" do
      before { create_list(:variant, (default_per_page + 1), product: product) }
      let(:default_per_page) { Spree::Backend::Config[:variants_per_page] }

      it 'allows to change number of displayed variants', js: true do
        second_page_link_selector = "a[href='#{spree.admin_product_variants_path(product, page: 2)}']"
        visit spree.admin_product_variants_path(product)
        expect(page).to have_css(second_page_link_selector)
        page.select('50', from: 'per_page')
        expect(page).to have_current_path(spree.admin_product_variants_path(product, per_page: 50))
        expect(page).not_to have_css(second_page_link_selector)
      end

      it 'allows to go to the second page' do
        visit spree.admin_product_variants_path(product)
        page.click_link('2')
        expect(page).to have_current_path(spree.admin_product_variants_path(product, page: 2))
      end
    end

    context 'currency displaying' do
      context 'using Russian Rubles' do
        before do
          Spree::Config[:currency] = 'RUB'
          Spree::Store.default.update!(default_currency: 'RUB')
          create(:variant, product: product, price: 19.99)
        end

        # Regression test for #2737
        context 'uses руб as the currency symbol' do
          it 'on the products listing page' do
            visit spree.admin_product_variants_path(product)
            within_row(1) { expect(page).to have_content('19.99 ₽') }
          end
        end
      end
    end
  end
end
