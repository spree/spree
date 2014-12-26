require 'spec_helper'

describe "Taxonomies and taxons", :type => :feature, js: true do
  stub_authorization!

  it "admin should be able to edit taxon" do

    visit spree.new_admin_taxonomy_path

    fill_in "Name", :with => "Hello"
    click_button "Create"

    @taxonomy = Spree::Taxonomy.last

    visit spree.edit_admin_taxonomy_taxon_path(@taxonomy, @taxonomy.root.id)

    fill_in "taxon_name", :with => "Shirt"
    fill_in "taxon_description", :with => "Discover our new rails shirts"

    fill_in "permalink_part", :with => "shirt-rails"
    click_button "Update"
    expect(page).to have_content("Taxon \"Shirt\" has been successfully updated!")
  end

  it "admin should be able to remove a product from a taxon", type: :feature, js: true do
    taxon_1 = create(:taxon, name: 'Clothing')
    product = create(:product)
    product.taxons << taxon_1

    visit spree.admin_taxons_path
    select_clothing_from_select2

    find('.product').hover
    find('.product .dropdown-toggle').click
    # TODO: This should be a click_link "Delete from taxon"
    page.execute_script("$('.js-delete-product').click()")
    wait_for_ajax

    visit current_path
    select_clothing_from_select2

    expect(page).to have_content("No results")
  end

  def select_clothing_from_select2
    page.execute_script %Q{$('#s2id_taxon_id').select2('open')}
    select_select2_result("Clothing")
    wait_for_ajax
  end
end
