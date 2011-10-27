require 'spec_helper'

describe "States" do
  before(:each) do
    visit admin_path
    click_link "Configuration"
  end

  context "admin visiting states listing" do
    it "should correctly display the states" do
      pending
      Factory(:zone)
      country = Factory(:country)
      Factory(:state, :country => country)
      Factory(:state, :name => "Maryland", :abbr => "MD", :country => country)
      params[:country_id] = country.id
      click_link "States"
      save_and_open_page
      find('table#listing_states tbody tr:nth-child(1) td:nth-child(1)').text.should == State.limit(1).order('name asc').to_a.first.anem
    end
  end
end
