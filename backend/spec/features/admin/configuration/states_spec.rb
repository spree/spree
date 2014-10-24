require 'spec_helper'

describe "States", :type => :feature do
  stub_authorization!

  let!(:country) { create(:country) }

  before(:each) do
    @hungary = Spree::Country.create!(:name => "Hungary", :iso_name => "Hungary")
  end

  # TODO: For whatever reason, rendering of the states page takes a non-trivial amount of time
  # Therefore we navigate to it, and wait until what we see is visible
  def go_to_states_page
    visit spree.admin_country_states_path(country)
    counter = 0
    until page.has_css?("#new_state_link")
      if counter < 10
        sleep(2)
        counter += 1
      else
        raise "Could not see new state link!"
      end
    end
  end

  context "admin visiting states listing" do
    let!(:state) { create(:state, :country => country) }

    it "should correctly display the states" do
      visit spree.admin_country_states_path(country)
      expect(page).to have_content(state.name)
    end
  end

  context "creating and editing states" do
    it "should allow an admin to edit existing states", :js => true do
      go_to_states_page
      set_select2_field("country", country.id)

      click_link "new_state_link"
      fill_in "state_name", :with => "Calgary"
      fill_in "Abbreviation", :with => "CL"
      click_button "Create"
      expect(page).to have_content("successfully created!")
      expect(page).to have_content("Calgary")
    end

    it "should allow an admin to create states for non default countries", :js => true do
      go_to_states_page
      set_select2_field "#country", @hungary.id
      # Just so the change event actually gets triggered in this spec
      # It is definitely triggered in the "real world"
      page.execute_script("$('#country').trigger('change');")

      click_link "new_state_link"
      wait_for_ajax

      fill_in "state_name", :with => "Pest megye"
      fill_in "Abbreviation", :with => "PE"
      click_button "Create"
      expect(page).to have_content("successfully created!")
      expect(page).to have_content("Pest megye")
      expect(find("#s2id_country span").text).to eq("Hungary")
    end

    it "should show validation errors", :js => true do
      go_to_states_page
      set_select2_field("country", country.id)

      click_link "new_state_link"

      fill_in "state_name", :with => ""
      fill_in "Abbreviation", :with => ""
      click_button "Create"
      expect(page).to have_content("Name can't be blank")
    end
  end
end
