require 'spec_helper'

describe "Product Variants" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
  end

  context "editing variant option types", :js => true do
    let!(:product) { create(:product) }

    it "should allow an admin to create option types for a variant" do
      click_link "Products"

      within_row(1) { click_icon :edit }

      within('#sidebar') { click_link "Variants" }
      page.should have_content("TO ADD VARIANTS, YOU MUST FIRST DEFINE")
    end

    it "allows admin to create a variant if there are option types" do
      click_link "Products"
      click_link "Option Types"
      click_link "new_option_type_link"
      fill_in "option_type_name", :with => "shirt colors"
      fill_in "option_type_presentation", :with => "colors"
      click_button "Create"
      page.should have_content("successfully created!")

      page.find('#option_type_option_values_attributes_0_name').set('color')
      page.find('#option_type_option_values_attributes_0_presentation').set('black')
      click_button "Update"
      page.should have_content("successfully updated!")

      visit spree.admin_path
      click_link "Products"
      within('table.index tbody tr:nth-child(1)') do
        click_icon :edit
      end

      select2_search "shirt", :from => "Option Types"
      click_button "Update"
      page.should have_content("successfully updated!")

      within('#sidebar') { click_link "Variants" }
      click_link "New Variant"

      targetted_select2 "black", :from => "#s2id_variant_option_value_ids"
      fill_in "variant_sku", :with => "A100"
      click_button "Create"
      page.should have_content("successfully created!")

      within(".index") do
        page.should have_content("19.99")
        page.should have_content("black")
        page.should have_content("A100")
      end
    end
  end
end
