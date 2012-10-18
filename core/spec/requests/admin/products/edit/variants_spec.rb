require 'spec_helper'

describe "Product Variants" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
  end

  context "editing variant option types", :js => true do
    it "should allow an admin to create option types for a variant" do
      create(:product)

      click_link "Products"
      within('table.index tr:nth-child(2)') { click_link "Edit" }
      within('#sidebar') { click_link "Variants" }
      page.should have_content("To add variants, you must first define")
    end

    it "should allow an admin to create a variant if there are option types" do
      click_link "Products"
      click_link "Option Types"
      click_link "new_option_type_link"
      fill_in "option_type_name", :with => "shirt colors"
      fill_in "option_type_presentation", :with => "colors"
      click_button "Create"
      page.should have_content("successfully created!")

      within('#new_add_option_value') { click_link "Add Option Value" }
      page.find('table tr:last td.name input').set('color')
      page.find('table tr:last td.presentation input').set('black')
      click_button "Update"
      page.should have_content("successfully updated!")

      create(:product)

      visit spree.admin_path
      click_link "Products"
      within('table.index tr:nth-child(2)') { click_link "Edit" }
      select "colors", :from => "Option Types"
      click_button "Update"
      page.should have_content("successfully updated!")

      within('#sidebar') { click_link "Variants" }
      click_link "New Variant"
      fill_in "variant_sku", :with => "A100"
      click_button "Create"
      page.should have_content("successfully created!")
      within(".index") do
        page.should have_content("19.99")
        page.should have_content("A100")
      end
    end
  end
end
