require 'spec_helper'

describe 'Edit Product Stores', type: :feature, js: true do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:product) { create(:product, stores: [store]) }
  let!(:store_2) { create(:store) }
  let!(:store_3) { create(:store) }

  before do
    visit spree.edit_admin_product_path(product)
  end

  it 'allows assigning multiple stores' do
    select2 store_3.unique_name, from: 'Stores'

    click_button 'Update'

    expect(page).to have_content('successfully updated')

    expect(product.reload.stores).to contain_exactly(store, store_3)
  end
end
