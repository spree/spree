require 'spec_helper'

describe "States" do
  before(:each) do
    visit spree.admin_path
    click_link "Configuration"
  end

  context "admin visiting states listing" do
    before(:each) do
      Factory(:zone)
    end

    it "should correctly display the states" do
      pending
      click_link "States"
      find('table#listing_states tbody tr:nth-child(1) td:nth-child(1)').text.should == Spree::State.limit(1).order('name asc').to_a.first.name.downcase.capitalize
    end
  end

  context "creating and editing states" do
    it "should allow an admin to edit existing states", :js => true do
      pending
      click_link "States"
      select "Canada", :from => "country"
      click_link "new_state_link"
      fill_in "state_name", :with => "Calgary"
      fill_in "Abbreviation", :with => "CL"
      click_button "Create"
      page.should have_content("successfully created!")
      page.should have_content("Calgary")

      within('table#listing_states tbody tr:nth-child(1)') { click_link "Edit" }
      page.should have_content("Editing State")
      click_link "States"
      select "Canada", :from => "country"
      page.should have_content("Calgary")
    end

    it "should show validation errors", :js => true do
      pending
      click_link "States"
      select "Canada", :from => "country"
      click_link "new_state_link"
      fill_in "state_name", :with => ""
      fill_in "Abbreviation", :with => ""
      click_button "Create"
      page.should have_content("Name can't be blank")
    end
  end
end
