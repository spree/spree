require 'spec_helper'

describe "States" do
  stub_authorization!

  let!(:country) { create(:country) }

  before(:each) do
    Spree::Config[:default_country_id] = country.id

    visit spree.admin_path
    click_link "Configuration"
  end

  context "admin visiting states listing" do
    let!(:state) { create(:state, :country => country) }

    it "should correctly display the states" do
      click_link "States"
      page.should have_content(state.name)
    end
  end

  context "creating and editing states" do
    it "should allow an admin to edit existing states", :js => true do
      click_link "States"
      wait_until do
        page.should have_selector('#country', :visible => true)
      end
      select country.name, :from => "Country"
      click_link "new_state_link"
      fill_in "state_name", :with => "Calgary"
      fill_in "Abbreviation", :with => "CL"
      click_button "Create"
      page.should have_content("successfully created!")
      page.should have_content("Calgary")
    end

    it "should show validation errors", :js => true do
      click_link "States"
      select country.name, :from => "country"
      click_link "new_state_link"
      fill_in "state_name", :with => ""
      fill_in "Abbreviation", :with => ""
      click_button "Create"
      page.should have_content("Name can't be blank")
    end
  end
end
