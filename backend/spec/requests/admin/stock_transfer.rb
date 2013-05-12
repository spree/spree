require 'spec_helper'

describe 'Stock Transfers' do
  stub_authorization!

  it 'transfer between 2 locations', :js => true do
    source_location = create(:stock_location_with_items, :name => 'NY')
    destination_location = create(:stock_location, :name => 'SF')

    visit spree.new_admin_stock_transfer_path

    fill_in 'reference', :with => 'PO 666'

    click_button 'Add'
    click_button 'Transfer Stock'

    page.should have_content('Reference Number: PO 666')
    page.should have_content('NY')
    page.should have_content('SF')

    transfer = Spree::StockTransfer.last
    transfer.should have(2).stock_movements
  end

  describe 'received stock transfer' do
    def it_is_received_stock_transfer(page)
      page.should have_content('Reference Number: PO 666')
      page.should_not have_content('Source')
      page.should have_content('Destination')

      transfer = Spree::StockTransfer.last
      transfer.should have(1).stock_movements
      transfer.source_location.should be_nil
    end

    it 'receive stock to a single location', :js => true do
      source_location = create(:stock_location_with_items, :name => 'NY')
      destination_location = create(:stock_location, :name => 'SF')

      visit spree.new_admin_stock_transfer_path

      fill_in 'reference', :with => 'PO 666'
      check 'transfer_receive_stock'
      select('NY', :from => 'transfer_destination_location_id')

      click_button 'Add'
      click_button 'Transfer Stock'

      it_is_received_stock_transfer page
    end

    it 'forced to only receive there is only one location', :js => true do
      source_location = create(:stock_location_with_items, :name => 'NY')

      visit spree.new_admin_stock_transfer_path

      fill_in 'reference', :with => 'PO 666'

      find('#transfer_receive_stock').should be_checked

      select('NY', :from => 'transfer_destination_location_id')

      click_button 'Add'
      click_button 'Transfer Stock'

      it_is_received_stock_transfer page
    end
  end
end
