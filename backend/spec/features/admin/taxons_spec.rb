require 'spec_helper'

describe 'Taxonomies and taxons', type: :feature do
  stub_authorization!

  let(:taxonomy) { create(:taxonomy, name: 'Hello') }

  it 'admin should be able to edit taxon' do
    visit spree.edit_admin_taxonomy_taxon_path(taxonomy, taxonomy.root.id)

    fill_in 'taxon_name', with: 'Shirt'
    fill_in 'taxon_description', with: 'Discover our new rails shirts'

    fill_in 'permalink_part', with: 'shirt-rails'
    click_button 'Update'
    expect(page).to have_content('Taxon "Shirt" has been successfully updated!')
  end

  it 'taxon without name should not be updated' do
    visit spree.edit_admin_taxonomy_taxon_path(taxonomy, taxonomy.root.id)

    fill_in 'taxon_name', with: ''
    fill_in 'taxon_description', with: 'Discover our new rails shirts'

    fill_in 'permalink_part', with: 'shirt-rails'
    click_button 'Update'
    expect(page).to have_content("Name can't be blank")
  end

  it 'admin should be able to remove a product from a taxon', js: true do
    taxon_1 = create(:taxon, name: 'Clothing')
    product = create(:product)
    product.taxons << taxon_1

    visit spree.admin_taxons_path
    select_clothing_from_select2

    find('.product').hover
    find('.product .dropdown-toggle').click

    click_link 'Delete From Taxon'

    expect(page).not_to have_css('.product')

    refresh
    select_clothing_from_select2

    expect(page).to have_content('No results')
  end

  def select_clothing_from_select2
    select2 'Clothing', css: '.taxon-products-view', search: true
  end
end
