require 'spec_helper'

describe Spree::State do
  context "shoulda validations" do
    it {should belong_to(:country) }
    it {should have_one(:zone_member) }
    it {should have_one(:zone) }
    it {should validate_presence_of(:name) }
    it {should validate_presence_of(:country) }
    it { should have_valid_factory(:state) }
  end

  before(:all) do
    Spree::State.destroy_all
  end

  it "can find a state by name or abbr" do
    state = create(:state, :name => "California", :abbr => "CA")
    Spree::State.find_all_by_name_or_abbr("California").should include(state)
    Spree::State.find_all_by_name_or_abbr("CA").should include(state)
  end

  it "can find all states group by country id" do
    state = create(:state)
    Spree::State.states_group_by_country_id.should == { state.country_id.to_s => [[state.id, state.name]] }
  end
end
