require 'spec_helper'

feature "Taxonomies and taxons" do
  stub_authorization!

  scenario "admin should be able to edit taxon" do
    visit spree.new_admin_taxonomy_path

    fill_in "Name", with: "Hello"
    click_button "Create"

    @taxonomy = Spree::Taxonomy.last

    visit spree.edit_admin_taxonomy_taxon_path(@taxonomy, @taxonomy.root.id)

    fill_in "taxon_name", with: "Shirt"
    fill_in "taxon_description", with: "Discover our new rails shirts"

    fill_in "permalink_part", with: "shirt-rails"
    click_button "Update"
    expect(page).to have_content("Taxon \"Shirt\" has been successfully updated!")
  end

  scenario "admin should be able to remove a product from a taxon", js: true do
    taxon_1 = create(:taxon, name: 'Clothing')
    product = create(:product)
    product.taxons << taxon_1

    visit spree.admin_taxons_path
    select_clothing_from_select2

    find('.product').hover
    find('.product .dropdown-toggle').click
    click_link "Delete From Taxon"
    wait_for_ajax

    visit current_path
    select_clothing_from_select2

    expect(page).to have_content("No results")
  end

  def select_clothing_from_select2
    targetted_select2_search "Clothing", from: "#s2id_taxon_id"
    wait_for_ajax
  end
end
