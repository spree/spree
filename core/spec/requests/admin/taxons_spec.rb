require 'spec_helper'

describe "Taxons" do
  stub_authorization!
  let!(:taxonomy) { create(:taxonomy, :name => "Category") }
  let!(:clothing) { taxonomy.root.children.create(:name => "Clothing", :taxonomy_id => taxonomy.id) }

  context "edit taxon" do
    it "will update the taxon with updated values" do
      visit spree.edit_admin_taxonomy_taxon_path(taxonomy, clothing.id)
      fill_in "Description", :with => "The finest clothing you can imagen!"
      click_button "Update"
      page.should have_content "Taxon \"Clothing\" has been successfully updated!"
    end
  end
end