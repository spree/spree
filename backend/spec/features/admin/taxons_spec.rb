require 'spec_helper'

describe 'Taxonomies and taxons', type: :feature, js: true do
  stub_authorization!

  let(:taxonomy) { create(:taxonomy, name: 'Hello') }
  let(:file_path) { Rails.root + '../../spec/support/ror_ringer.jpeg' }

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

    click_link 'Remove'

    expect(page).not_to have_css('.product')

    refresh
    select_clothing_from_select2

    expect(page).to have_content('No results')
  end

  it 'admin should be able to add taxon icon' do
    visit spree.edit_admin_taxonomy_taxon_path(taxonomy, taxonomy.root.id)

    attach_file('taxon_icon', file_path)
    click_button 'Update'

    expect(page).to have_content('successfully updated!')

    visit spree.edit_admin_taxonomy_taxon_path(taxonomy, taxonomy.root.id)

    expect(page).to have_css('#taxon_icon_field img')
  end

  it 'admin should be able to remove taxon icon' do
    add_icon_to_root_taxon

    visit spree.edit_admin_taxonomy_taxon_path(taxonomy, taxonomy.root.id)

    click_link 'Remove Image'

    expect(page).to have_content('Image has been successfully removed')
  end

  def select_clothing_from_select2
    select2_open css: '.taxon-products-view'
    select2_search 'Clothing', css: '.taxon-products-view'
    select2_select Spree::Product.first.taxons.first&.pretty_name, css: '.taxon-products-view'
  end

  def add_icon_to_root_taxon
    visit spree.edit_admin_taxonomy_taxon_path(taxonomy, taxonomy.root.id)
    attach_file('taxon_icon', file_path)
    click_button 'Update'
  end
end
