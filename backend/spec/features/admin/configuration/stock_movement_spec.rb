require 'spec_helper'

describe 'Stock Movements', type: :feature do
  stub_authorization!
  let!(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.first }
  let!(:stock_movement) { create(:stock_movement, stock_item: stock_item, quantity: 10) }

  describe 'listing' do
    before do
      visit spree.admin_stock_locations_path
      within "#spree_stock_location_#{stock_location.id}" do
        click_on 'Stock Movements'
      end
    end

    it 'renders list of stock movements for this stock location' do
      expect(page).to have_content(stock_item.variant.name)
      expect(page).to have_content(stock_item.variant.options_text)
      expect(page).to have_content(stock_movement.quantity)
    end
  end

  describe 'creation', js: true do
    let!(:product) { create(:product_in_stock) }

    before do
      visit spree.admin_stock_location_stock_movements_path(stock_location.id)
      click_on 'New Stock Movement', match: :first
    end

    it 'creates new stock movement' do
      fill_in 'Quantity', with: 10

      select2_open label: 'Stock Item'
      select2_search product.name, from: 'Stock Item'
      select2_select product.name, from: 'Stock Item', match: :first

      click_button 'Create'

      expect(page).to have_content(product.name)
      expect(page).to have_content(10)

      expect(page).to have_content('has been successfully created!')
    end
  end
end
