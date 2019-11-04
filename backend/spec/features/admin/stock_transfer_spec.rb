require 'spec_helper'

describe 'Stock Transfers', type: :feature, js: true do
  stub_authorization!

  it 'shows variants with options text' do
    create(:stock_location_with_items, name: 'NY')

    product = Spree::Product.first
    variant = create(:variant, product: product)
    variant.set_option_value('Color', 'Green')

    visit spree.admin_stock_transfers_path
    click_on 'New Stock Transfer'

    select2 variant.sku, from: 'Variant', search: true, match: :first

    content = "#{variant.name} (#{variant.options_text}) - #{variant.sku}"
    expect(page).to have_content(content)
  end

  it 'transfer between 2 locations' do
    create(:stock_location_with_items, name: 'NY') # source_location
    create(:stock_location, name: 'SF') # destination_location

    variant = Spree::Variant.last

    visit spree.admin_stock_transfers_path
    click_on 'New Stock Transfer'
    fill_in 'reference', with: 'PO 666'

    select2 variant.name, from: 'Variant', search: true

    click_button 'Add'
    click_button 'Transfer Stock'

    expect(page).to have_content('Reference PO 666')
    expect(page).to have_content('NY')
    expect(page).to have_content('SF')
    expect(page).to have_content(variant.name)

    transfer = Spree::StockTransfer.last
    expect(transfer.stock_movements.size).to eq 2
  end

  describe 'received stock transfer' do
    def it_is_received_stock_transfer(page)
      expect(page).to have_content('Reference PO 666')
      expect(page).not_to have_selector('#stock-location-source')
      expect(page).to have_selector('#stock-location-destination')

      transfer = Spree::StockTransfer.last
      expect(transfer.stock_movements.size).to eq 1
      expect(transfer.source_location).to be_nil
    end

    it 'receive stock to a single location' do
      create(:stock_location_with_items, name: 'NY') # source_location
      create(:stock_location, name: 'SF') # destination_location

      variant = Spree::Variant.last

      visit spree.new_admin_stock_transfer_path

      fill_in 'reference', with: 'PO 666'
      check 'transfer_receive_stock'
      select2 'NY', from: 'Destination'

      select2 variant.name, from: 'Variant', search: true

      click_button 'Add'
      click_button 'Transfer Stock'

      it_is_received_stock_transfer page
    end

    it 'forced to only receive there is only one location' do
      create(:stock_location_with_items, name: 'NY') # source_location
      variant = Spree::Variant.last

      visit spree.new_admin_stock_transfer_path

      fill_in 'reference', with: 'PO 666'

      select2 'NY', from: 'Destination'
      select2 variant.name, from: 'Variant', search: true

      click_button 'Add'
      click_button 'Transfer Stock'

      it_is_received_stock_transfer page
    end
  end
end
