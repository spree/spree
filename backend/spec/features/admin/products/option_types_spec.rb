require 'spec_helper'

describe "Option Types", type: :feature, js: true do
  stub_authorization!

  before(:each) do
    visit spree.admin_path
    click_link "Products"
  end

  context "listing option types" do
    it "should list existing option types" do
      create(:option_type, name: "tshirt-color", presentation: "Color")
      create(:option_type, name: "tshirt-size", presentation: "Size")
      click_link "Option Types"
      within("table#listing_option_types") do
        expect(page).to have_content("Color")
        expect(page).to have_content("tshirt-color")
        expect(page).to have_content("Size")
        expect(page).to have_content("tshirt-size")
      end
    end
  end

  context "creating a new option type" do
    it "should allow an admin to create a new option type" do
      click_link "Option Types"
      click_link "new_option_type_link"
      expect(page).to have_content("New Option Type")
      fill_in "option_type_name", with: "shirt colors"
      fill_in "option_type_presentation", with: "colors"
      click_button "Create"
      expect(page).to have_content("successfully created!")

      page.find('#option_type_option_values_attributes_0_name').set('color')
      page.find('#option_type_option_values_attributes_0_presentation').set('black')

      click_button "Update"
      expect(page).to have_content("successfully updated!")
    end
  end

  context "editing an existing option type" do
    it "should allow an admin to update an existing option type" do
      create(:option_type, name: "tshirt-color", presentation: "Color")
      create(:option_type, name: "tshirt-size", presentation: "Size")
      click_link "Option Types"
      within('table#listing_option_types') { click_icon :edit }
      fill_in "option_type_name", with: "foo-size 99"
      click_button "Update"
      expect(page).to have_content("successfully updated!")
      expect(page).to have_content("foo-size 99")
    end
  end

  # Regression test for #2277
  it "can remove an option value from an option type" do
    create(:option_value)
    click_link "Option Types"
    within('table#listing_option_types') { click_icon :edit }
    expect(page).to have_content("Editing Option Type")
    expect(all("tbody#option_values tr").count).to eq(1)
    within("tbody#option_values") do
      find('.spree_remove_fields').click
    end
    # Assert that the field is hidden automatically
    expect(all("tbody#option_values tr").select(&:visible?).count).to eq(0)

    # Then assert that on a page refresh that it's still not visible
    visit page.current_url
    # What *is* visible is a new option value field, with blank values
    # Sometimes the page doesn't load before the all check is done
    # lazily finding the element gives the page 10 seconds
    expect(page).to have_css("tbody#option_values")
    all("tbody#option_values tr input").all? { |input| input.value.blank? }
  end

  # Regression test for #3204
  it "can remove a non-persisted option value from an option type" do
    create(:option_type)
    click_link "Option Types"
    within('table#listing_option_types') { click_icon :edit }

    wait_for_ajax
    page.find("tbody#option_values", :visible => true)

    expect(all("tbody#option_values tr").select(&:visible?).count).to eq(1)

    # Add a new option type
    click_link "Add Option Value"
    expect(all("tbody#option_values tr").select(&:visible?).count).to eq(2)

    # Remove default option type
    within("tbody#option_values") do
      click_icon :delete
    end
    # Check that there was no HTTP request
    expect(all("div#progress[style]").count).to eq(0)
    # Assert that the field is hidden automatically
    expect(all("tbody#option_values tr").select(&:visible?).count).to eq(1)

    # Remove added option type
    within("tbody#option_values") do
      click_icon :delete
    end
    # Check that there was no HTTP request
    expect(all("div#progress[style]").count).to eq(0)
    # Assert that the field is hidden automatically
    expect(all("tbody#option_values tr").select(&:visible?).count).to eq(0)

  end

end
