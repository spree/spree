require 'spec_helper'

RSpec.describe Spree::OrderRouting::Rules::DefaultLocation, type: :model do
  let(:store) { @default_store }
  let(:order) { build(:order, store: store) }

  subject(:rule) { described_class.new(store: store, position: 1) }

  it 'ranks the default location 0 and others 1' do
    default_loc = create(:stock_location, default: true)
    secondary   = create(:stock_location, default: false)

    rankings = rule.rank(order, [default_loc, secondary])

    expect(rankings.find { |r| r.location == default_loc }.rank).to eq(0)
    expect(rankings.find { |r| r.location == secondary }.rank).to eq(1)
  end
end
