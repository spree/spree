require 'spec_helper'

describe 'Bulk Transfers' do
  stub_authorization!

  it 'transfer between 2 locations', :js => true do
    source_location = create(:stock_location_with_items, :name => 'NY')
    destination_location = create(:stock_location, :name => 'SF')

    visit spree.admin_bulk_transfer_path

    fill_in 'reference_number', :with => 'PO 666'

    click_button 'Add'
    click_button 'Transfer Stock'

    page.should have_content('Reference Number: PO 666')
    page.should have_content('source: NY')
    page.should have_content('destination: SF')

    transfer = Spree::StockTransfer.last
    transfer.should have(2).stock_movements
  end

  it 'receive stock to a single location', :js => true do
    source_location = create(:stock_location_with_items, :name => 'NY')
    destination_location = create(:stock_location, :name => 'SF')

    visit spree.admin_bulk_transfer_path

    fill_in 'reference_number', :with => 'PO 666'
    check 'bulk_receive_stock'
    select('NY', :from => 'bulk_destination_location_id')

    click_button 'Add'
    click_button 'Transfer Stock'

    page.should have_content('Reference Number: PO 666')
    page.should_not have_content('source:')
    page.should have_content('destination: NY')

    transfer = Spree::StockTransfer.last
    transfer.should have(1).stock_movements
    transfer.source_location.should be_nil
  end

  it 'forced to only receive there is only one location', :js => true do
    source_location = create(:stock_location_with_items, :name => 'NY')

    visit spree.admin_bulk_transfer_path

    fill_in 'reference_number', :with => 'PO 666'

    find('#bulk_receive_stock').should be_checked

    select('NY', :from => 'bulk_destination_location_id')

    click_button 'Add'
    click_button 'Transfer Stock'

    page.should have_content('Reference Number: PO 666')
    page.should_not have_content('source:')
    page.should have_content('destination: NY')

    transfer = Spree::StockTransfer.last
    transfer.should have(1).stock_movements
    transfer.source_location.should be_nil
  end
end
