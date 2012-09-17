require 'spec_helper'

describe "Prototypes" do
  stub_authorization!

  context "listing prototypes" do
    it "should be able to list existing prototypes" do
      create(:property, :name => "model", :presentation => "Model")
      create(:property, :name => "brand", :presentation => "Brand")
      create(:property, :name => "shirt_fabric", :presentation => "Fabric")
      create(:property, :name => "shirt_sleeve_length", :presentation => "Sleeve")
      create(:property, :name => "mug_type", :presentation => "Type")
      create(:property, :name => "bag_type", :presentation => "Type")
      create(:property, :name => "manufacturer", :presentation => "Manufacturer")
      create(:property, :name => "bag_size", :presentation => "Size")
      create(:property, :name => "mug_size", :presentation => "Size")
      create(:property, :name => "gender", :presentation => "Gender")
      create(:property, :name => "shirt_fit", :presentation => "Fit")
      create(:property, :name => "bag_material", :presentation => "Material")
      create(:property, :name => "shirt_type", :presentation => "Type")
      p = create(:prototype, :name => "Shirt")
      %w( brand gender manufacturer model shirt_fabric shirt_fit shirt_sleeve_length shirt_type ).each do |prop|
        p.properties << Spree::Property.find_by_name(prop)
      end
      p = create(:prototype, :name => "Mug")
      %w( mug_size mug_type ).each do |prop|
        p.properties << Spree::Property.find_by_name(prop)
      end
      p = create(:prototype, :name => "Bag")
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

  context "editing a prototype" do
    it "should allow to empty its properties" do
      create(:property, :name => "model", :presentation => "Model")
      create(:property, :name => "brand", :presentation => "Brand")

      shirt_prototype = create(:prototype, :name => "Shirt", :properties => [])
      %w( brand model ).each do |prop|
        shirt_prototype.properties << Spree::Property.find_by_name(prop)
      end

      visit spree.admin_path
      click_link "Products"
      click_link "Prototypes"

      click_on "Edit"

      page.should have_checked_field('brand')
      page.should have_checked_field('model')

      page.uncheck('brand')
      page.uncheck('model')

      click_button 'Update'

      click_on "Edit"

      page.should have_unchecked_field('brand')
      page.should have_unchecked_field('model')
    end
  end
end
