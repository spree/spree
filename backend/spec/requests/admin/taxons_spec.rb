require 'spec_helper'

describe "Taxonomies and taxons" do
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
    page.should have_content("Taxon \"Shirt\" has been successfully updated!")
  end

end
