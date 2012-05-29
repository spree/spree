require 'spec_helper'

describe "Tax Categories" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
  end

  context "admin visiting tax categories list" do
    it "should display the existing tax categories" do
      create(:tax_category, :name => "Clothing", :description => "For Clothing")
      click_link "Tax Categories"
      page.should have_content("Listing Tax Categories")
      find('table#listing_tax_categories tbody tr td:nth-child(1)').text.should == "Clothing"
      find('table#listing_tax_categories tbody tr td:nth-child(2)').text.should == "For Clothing"
      find('table#listing_tax_categories tbody tr td:nth-child(3)').text.should == "False"
    end
  end

  context "admin creating new tax category" do
    before(:each) do
      click_link "Tax Categories"
      click_link "admin_new_tax_categories_link"
    end

    it "should be able to create new tax category" do
      page.should have_content("New Tax Category")
      fill_in "tax_category_name", :with => "sports goods"
      fill_in "tax_category_description", :with => "sports goods desc"
      click_button "Create"
      page.should have_content("successfully created!")
    end

    it "should show validation errors if there are any" do
      click_button "Create"
      page.should have_content("Name can't be blank")
    end
  end

  context "admin editing a tax category" do
    it "should be able to update an existing tax category" do
      create(:tax_category)
      click_link "Tax Categories"
      within(:css, 'table#listing_tax_categories tbody tr:nth-child(1)') { click_link "Edit" }
      fill_in "tax_category_description", :with => "desc 99"
      click_button "Update"
      page.should have_content("successfully updated!")
      page.should have_content("desc 99")
    end
  end
end
