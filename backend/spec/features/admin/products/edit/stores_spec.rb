require 'spec_helper'

describe 'Product Stores', type: :feature, js: true do
  stub_authorization!

  before do
    create(:product, stores: Spree::Store.all)
    create(:store, name: 'First store', code: 'first')
    create(:store, name: 'Second store', code: 'second')

    visit spree.admin_products_path

    within_row(1) { click_icon :edit }
  end

  it 'allows assigning products' do
    select2 'First store', from: 'Stores'
    select2 'Second store', from: 'Stores'

    click_button 'Update'

    expect(page).to have_content('successfully updated')

    expect(page).to have_content('First store')
    expect(page).to have_content('Second store')
  end
end
