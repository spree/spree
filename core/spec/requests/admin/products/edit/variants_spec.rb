require 'spec_helper'

describe "Product Variants" do
  before(:each) do
    visit spree.admin_path
  end

  context "editing variant option types", :js => true do
    it "should allow an admin to create option types for a variant" do
      create(:product, :name => 'apache baseball cap', :sku => 'A100', :available_on => "2011-01-01 01:01:01")
      create(:product, :name => 'apache baseball cap2', :sku => 'B100', :available_on => "2011-01-01 01:01:01")
      create(:product, :name => 'zomg shirt', :sku => 'Z100', :available_on => "2011-01-01 01:01:01")
      Spree::Product.update_all :count_on_hand => 10

      click_link "Products"
      within('table.index tr:nth-child(2)') { click_link "Edit" }
      within('#sidebar') { click_link "Variants" }
      find('table.index tbody tr:nth-child(2) td:nth-child(1)').text.should == "None"
      page.should have_content("To add variants, you must first define")
      within('.first_add_option_types') { click_link "Option Types" }
      within('#new_opt_link') { click_link "Add Option Type" }
      page.should have_content("None Available")
    end

    it "should allow an admin to edit existing option types" do
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

      create(:product, :name => 'apache baseball cap', :sku => 'A100', :available_on => "2011-01-01 01:01:01")
      create(:product, :name => 'apache baseball cap2', :sku => 'B100', :available_on => "2011-01-01 01:01:01")
      create(:product, :name => 'zomg shirt', :sku => 'Z100', :available_on => "2011-01-01 01:01:01")
      Spree::Product.update_all :count_on_hand => 10

      visit spree.admin_path
      click_link "Products"
      within('table.index tr:nth-child(2)') { click_link "Edit" }
      within('#sidebar') { click_link "Option Types" }
      within('#new_opt_link') { click_link "Add Option Type" }
      within('#option-types') { click_link "Select" }
      within(".index") do
        page.should have_content("shirt colors")
      end

      visit spree.admin_path
      click_link "Products"
      within('table.index tr:nth-child(2)') { click_link "Edit" }
      within('#sidebar') { click_link "Variants" }
      within('#new_var_link') { click_link "New Variant" }
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
