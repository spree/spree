require 'spec_helper'

describe 'Product Properties', type: :feature, js: true do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:product) { create(:product, stores: [store]) }

  let!(:brand_property) { create(:property, name: 'brand', presentation: 'Brand', position: 1) }
  let!(:material_property) { create(:property, name: 'material', presentation: 'Material', position: 2) }

  before do
    product.set_property('brand', 'Epsilon')
  end

  it 'shows associated properties in the form plus a new property' do
    visit spree.edit_admin_product_path(product)
    expect(page).to have_content('brand')
    expect(page).to have_field('product_product_properties_attributes_0_value', with: 'Epsilon')
    expect(page).to have_content('material')
    expect(page).to have_field('product_product_properties_attributes_1_value', with: '')

    fill_in 'product_product_properties_attributes_1_value', with: 'Cotton'
    within('#page-header') { click_button 'Update' }

    expect(page).to have_content('successfully updated!')

    expect(product.reload.property('material')).to eq('Cotton')
    expect(product.property('brand')).to eq('Epsilon')

    expect(page).to have_field('product_product_properties_attributes_0_value', with: 'Epsilon')
    expect(page).to have_field('product_product_properties_attributes_1_value', with: 'Cotton')
  end
end
