require 'spec_helper'

describe 'Product Details', type: :feature, js: true do
  stub_authorization!

  context 'editing a product' do
    before do
      create(:product, name: 'Bún thịt nướng', sku: 'A100',
                       description: 'lorem ipsum', available_on: '2013-08-14 01:02:03')

      visit spree.admin_products_path
      within_row(1) { click_icon :edit }
    end

    it 'lists the product details' do
      click_link 'Details'

      expect(page).to have_css('.content-header h1', text: 'Products / Bún thịt nướng')
      expect(page).to have_field(id: 'product_name', with: 'Bún thịt nướng')
      expect(page).to have_field(id: 'product_slug', with: 'bun-th-t-n-ng')
      expect(page).to have_field(id: 'product_description', with: 'lorem ipsum')
      expect(page).to have_field(id: 'product_price', with: '19.99')
      expect(page).to have_field(id: 'product_cost_price', with: '17.00')
      expect(page).to have_field(id: 'product_available_on', with: '2013/08/14')
      expect(page).to have_field(id: 'product_sku', with: 'A100')
    end

    it 'handles slug changes' do
      fill_in 'product_slug', with: 'random-slug-value'
      click_button 'Update'
      expect(page).to have_content('successfully updated!')
    end

    it 'has a link to preview a product' do
      allow(Spree::Core::Engine).to receive(:frontend_available?).and_return(true)
      allow_any_instance_of(Spree::BaseHelper).to receive(:product_url).and_return('http://example.com/products/product-slug')
      click_link 'Details'
      expect(page).to have_css('#admin_preview_product')
      expect(page).to have_link Spree.t(:preview_product), href: 'http://example.com/products/product-slug'
    end
  end
end
