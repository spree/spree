require 'spec_helper'

describe "Properties" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Products"
  end

  context "listing product properties" do
    it "should list the existing product properties" do
      create(:property, :name => 'shirt size', :presentation => 'size')
      create(:property, :name => 'shirt fit', :presentation => 'fit')

      click_link "Properties"
      within_row(1) do
        column_text(1).should == "shirt size"
        column_text(2).should == "size"
      end

      within_row(2) do
        column_text(1).should == "shirt fit"
        column_text(2).should == "fit"
      end
    end
  end

  context "creating a property" do
    it "should allow an admin to create a new product property", :js => true do
      click_link "Properties"
      click_link "new_property_link"
      within('#new_property') { page.should have_content("NEW PROPERTY") }

      fill_in "property_name", :with => "color of band"
      fill_in "property_presentation", :with => "color"
      click_button "Create"
      page.should have_content("successfully created!")
    end
  end

  context "editing a property" do
    before(:each) do
      create(:property)
      click_link "Properties"
      within_row(1) { click_icon :edit }
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

  context "linking a property to a product", :js => true do
    before do
      create(:product)
      visit spree.admin_products_path
      click_icon :edit
      click_link "Product Properties"
    end

    # Regression test for #2279
    it "successfully create and then remove product property" do
      fill_in_property
      # Sometimes the page doesn't load before the all check is done
      # lazily finding the element gives the page 10 seconds
      page.should have_css("tbody#product_properties")
      all("tbody#product_properties tr").count.should == 2

      delete_product_property

      check_property_row_count(1)
    end

    # Regression test for #4466
    it "successfully remove and create a product property at the same time" do
      fill_in_property

      fill_in "product_product_properties_attributes_1_property_name", :with => "New Property"
      fill_in "product_product_properties_attributes_1_value", :with => "New Value"

      delete_product_property

      # Give fadeOut time to complete
      page.should_not have_selector("#product_product_properties_attributes_0_property_name")
      page.should_not have_selector("#product_product_properties_attributes_0_value")

      click_button "Update"

      page.should_not have_content("Product is not found")

      check_property_row_count(2)
    end

    def fill_in_property
      page.should have_content('Editing Product')
      fill_in "product_product_properties_attributes_0_property_name", :with => "A Property"
      fill_in "product_product_properties_attributes_0_value", :with => "A Value"
      click_button "Update"
      click_link "Product Properties"
    end

    def delete_product_property
      page.evaluate_script('window.confirm = function() { return true; }')
      click_icon :trash
      wait_for_ajax # delete action must finish before reloading
    end

    def check_property_row_count(expected_row_count)
      click_link "Product Properties"
      page.should have_css("tbody#product_properties")
      all("tbody#product_properties tr").count.should == expected_row_count
    end
  end
end
