require 'spec_helper'

RSpec.describe Spree::OrderRouting::Rules::PreferredLocation, type: :model do
  let(:store) { @default_store }
  let(:preferred) { create(:stock_location, name: 'Preferred') }
  let(:other)     { create(:stock_location, name: 'Other') }
  let(:locations) { [preferred, other] }

  subject(:rule) { described_class.new(store: store, position: 1) }

  context 'when the order has a preferred_stock_location_id' do
    let(:order) { build(:order, store: store, preferred_stock_location: preferred) }

    it 'ranks the preferred location 0 and abstains for others' do
      rankings = rule.rank(order, locations)
      expect(rankings.find { |r| r.location == preferred }.rank).to eq(0)
      expect(rankings.find { |r| r.location == other }.rank).to be_nil
    end
  end

  context 'when no preferred location is set' do
    let(:order) { build(:order, store: store) }

    it 'abstains for every location' do
      rankings = rule.rank(order, locations)
      expect(rankings.map(&:rank)).to all(be_nil)
    end
  end
end
