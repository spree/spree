require 'spec_helper'

describe 'Bulk Transfers' do
  stub_authorization!

  it 'admin should be able to edit taxon', :js => true do
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
end
