require 'spec_helper'

describe Spree::State, type: :model do
  describe 'Associations' do
    it { is_expected.to have_many(:addresses).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:country) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:country_id).case_insensitive }
    it { is_expected.to validate_uniqueness_of(:abbr).scoped_to(:country_id).case_insensitive }
  end

  it "can find a state by name or abbr" do
    state = create(:state, name: "California", abbr: "CA")
    expect(Spree::State.find_all_by_name_or_abbr("California")).to include(state)
    expect(Spree::State.find_all_by_name_or_abbr("CA")).to include(state)
  end

  it "can find all states group by country id" do
    state = create(:state)
    expect(Spree::State.states_group_by_country_id).to eq({ state.country_id.to_s => [[state.id, state.name]] })
  end

  describe 'whitelisted_ransackable_attributes' do
    it { expect(Spree::State.whitelisted_ransackable_attributes).to eq(%w(abbr)) }
  end
end
