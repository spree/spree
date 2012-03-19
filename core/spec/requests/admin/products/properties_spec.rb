require 'spec_helper'

describe "Properties" do
  before(:each) do
    visit spree.admin_path
    click_link "Products"
  end

  context "listing product properties" do
    it "should list the existing product properties" do
      Factory(:property, :name => 'shirt size', :presentation => 'size')
      Factory(:property, :name => 'shirt fit', :presentation => 'fit')

      click_link "Properties"
      find('table#listing_properties tbody tr:nth-child(1) td:nth-child(1)').text.should == "shirt size"
      find('table#listing_properties tbody tr:nth-child(1) td:nth-child(2)').text.should == "size"
      find('table#listing_properties tbody tr:nth-child(2) td:nth-child(1)').text.should == "shirt fit"
      find('table#listing_properties tbody tr:nth-child(2) td:nth-child(2)').text.should == "fit"
    end
  end

  context "creating a property" do
    it "should allow an admin to create a new product property", :js => true do
      click_link "Properties"
      click_link "new_property_link"
      within('#new_property') { page.should have_content("New Property") }

      fill_in "property_name", :with => "color of band"
      fill_in "property_presentation", :with => "color"
      click_button "Create"
      page.should have_content("successfully created!")
    end
  end

  context "editing a property" do
    before(:each) do
      Factory(:property)
      click_link "Properties"
      within('table#listing_properties tbody tr:nth-child(1)') { click_link "Edit" }
    end

    it "should allow an admin to edit an existing product property" do
      fill_in "property_name", :with => "model 99"
      click_button "Update"
      page.should have_content("successfully updated!")
      page.should have_content("model 99")
    end

    it "should show validation errors" do
      fill_in "property_name", :with => ""
      click_button "Update"
      page.should have_content("Name can't be blank")
    end
  end
end
