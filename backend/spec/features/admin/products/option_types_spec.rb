require 'spec_helper'

describe "Option Types" do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Products"
  end

  context "listing option types" do
    it "should list existing option types" do
      create(:option_type, :name => "tshirt-color", :presentation => "Color")
      create(:option_type, :name => "tshirt-size", :presentation => "Size")

      click_link "Option Types"
      within("table#listing_option_types") do
        page.should have_content("Color")
        page.should have_content("tshirt-color")
        page.should have_content("Size")
        page.should have_content("tshirt-size")
      end
    end
  end

  context "creating a new option type" do
    it "should allow an admin to create a new option type", :js => true do
      click_link "Option Types"
      click_link "new_option_type_link"
      page.should have_content("NEW OPTION TYPE")
      fill_in "option_type_name", :with => "shirt colors"
      fill_in "option_type_presentation", :with => "colors"
      click_button "Create"
      page.should have_content("successfully created!")

      page.find('#option_type_option_values_attributes_0_name').set('color')
      page.find('#option_type_option_values_attributes_0_presentation').set('black')

      click_button "Update"
      page.should have_content("successfully updated!")
    end
  end

  context "editing an existing option type" do
    it "should allow an admin to update an existing option type" do
      create(:option_type, :name => "tshirt-color", :presentation => "Color")
      create(:option_type, :name => "tshirt-size", :presentation => "Size")
      click_link "Option Types"
      within('table#listing_option_types') { click_link "Edit" }
      fill_in "option_type_name", :with => "foo-size 99"
      click_button "Update"
      page.should have_content("successfully updated!")
      page.should have_content("foo-size 99")
    end
  end

  # Regression test for #2277
  it "can remove an option value from an option type", :js => true do
    create(:option_value)
    click_link "Option Types"
    within('table#listing_option_types') { click_icon :edit }
    page.should have_content("Editing Option Type")
    all("tbody#option_values tr").count.should == 1
    within("tbody#option_values") do
      find('.spree_remove_fields').click
    end
    # Assert that the field is hidden automatically
    all("tbody#option_values tr").select(&:visible?).count.should == 0

    # Then assert that on a page refresh that it's still not visible
    visit page.current_url
    # What *is* visible is a new option value field, with blank values
    # Sometimes the page doesn't load before the all check is done
    # lazily finding the element gives the page 10 seconds
    page.should have_css("tbody#option_values")
    all("tbody#option_values tr input").all? { |input| input.value.blank? }
  end
  
  # Regression test for #3204
  it "can remove a non-persisted option value from an option type", :js => true do
    create(:option_type)
    click_link "Option Types"
    within('table#listing_option_types') { click_icon :edit }

    wait_for_ajax
    page.find("tbody#option_values", :visible => true)

    all("tbody#option_values tr").select(&:visible?).count.should == 1

    # Add a new option type
    click_link "Add Option Value"
    all("tbody#option_values tr").select(&:visible?).count.should == 2

    # Remove default option type
    within("tbody#option_values") do
      find('.icon-trash').click
    end
    # Check that there was no HTTP request
    all("div#progress[style]").count.should == 0
    # Assert that the field is hidden automatically
    all("tbody#option_values tr").select(&:visible?).count.should == 1

    # Remove added option type
    within("tbody#option_values") do
      find('.icon-trash').click
    end
    # Check that there was no HTTP request
    all("div#progress[style]").count.should == 0
    # Assert that the field is hidden automatically
    all("tbody#option_values tr").select(&:visible?).count.should == 0

  end

end
