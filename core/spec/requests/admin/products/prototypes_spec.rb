require 'spec_helper'

describe "Prototypes" do
  context "listing prototypes" do
    it "should be able to list existing prototypes" do
      Factory(:property, :name => "model", :presentation => "Model")
      Factory(:property, :name => "brand", :presentation => "Brand")
      Factory(:property, :name => "shirt_fabric", :presentation => "Fabric")
      Factory(:property, :name => "shirt_sleeve_length", :presentation => "Sleeve")
      Factory(:property, :name => "mug_type", :presentation => "Type")
      Factory(:property, :name => "bag_type", :presentation => "Type")
      Factory(:property, :name => "manufacturer", :presentation => "Manufacturer")
      Factory(:property, :name => "bag_size", :presentation => "Size")
      Factory(:property, :name => "mug_size", :presentation => "Size")
      Factory(:property, :name => "gender", :presentation => "Gender")
      Factory(:property, :name => "shirt_fit", :presentation => "Fit")
      Factory(:property, :name => "bag_material", :presentation => "Material")
      Factory(:property, :name => "shirt_type", :presentation => "Type")
      p = Factory(:prototype, :name => "Shirt")
      %w( brand gender manufacturer model shirt_fabric shirt_fit shirt_sleeve_length shirt_type ).each do |prop|
        p.properties << Spree::Property.find_by_name(prop)
      end
      p = Factory(:prototype, :name => "Mug")
      %w( mug_size mug_type ).each do |prop|
        p.properties << Spree::Property.find_by_name(prop)
      end
      p = Factory(:prototype, :name => "Bag")
      %w( bag_type bag_material ).each do |prop|
        p.properties << Spree::Property.find_by_name(prop)
      end

      visit spree.admin_path
      click_link "Products"
      click_link "Prototypes"

      find('table#listing_prototypes tbody tr:nth-child(1) td:nth-child(1)').text.should == "Shirt"
      find('table#listing_prototypes tbody tr:nth-child(2) td:nth-child(1)').text.should == "Mug"
      find('table#listing_prototypes tbody tr:nth-child(3) td:nth-child(1)').text.should == "Bag"
    end
  end

  context "creating a prototype" do
    it "should allow an admin to create a new product prototype", :js => true do
      visit spree.admin_path
      click_link "Products"
      click_link "Prototypes"
      click_link "new_prototype_link"
      within('#new_prototype') { page.should have_content("New Prototype") }
      fill_in "prototype_name", :with => "male shirts"
      click_button "Create"
      page.should have_content("successfully created!")
      click_link "Prototypes"
      within('table#listing_prototypes tbody tr:nth-child(1)') { click_link "Edit" }
      fill_in "prototype_name", :with => "Shirt 99"
      click_button "Update"
      page.should have_content("successfully updated!")
      page.should have_content("Shirt 99")
    end
  end
end
