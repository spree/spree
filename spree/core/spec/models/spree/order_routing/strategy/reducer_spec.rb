require 'spec_helper'

RSpec.describe Spree::OrderRouting::Strategy::Reducer, type: :model do
  let(:order) { build(:order, store: @default_store) }

  let(:loc_a) { create(:stock_location, name: 'A', default: true) }
  let(:loc_b) { create(:stock_location, name: 'B') }
  let(:loc_c) { create(:stock_location, name: 'C') }
  let(:locations) { [loc_a, loc_b, loc_c] }

  # Test rule that returns canned rankings instead of running real logic.
  def fake_rule(rankings)
    instance_double(Spree::OrderRoutingRule).tap do |dbl|
      allow(dbl).to receive(:rank) { |_o, _locs| rankings }
    end
  end

  def ranking(loc, rank)
    Spree::OrderRoutingRule::LocationRanking.new(location: loc, rank: rank)
  end

  it 'returns nil when no locations are eligible' do
    expect(described_class.new([], order: order).pick([])).to be_nil
  end

  it 'returns the unique winner of the first rule that has one' do
    rules = [
      fake_rule([ranking(loc_a, nil), ranking(loc_b, nil), ranking(loc_c, nil)]), # all abstain
      fake_rule([ranking(loc_a, 5),   ranking(loc_b, 1),   ranking(loc_c, 5)])    # B wins
    ]

    expect(described_class.new(rules, order: order).pick(locations)).to eq(loc_b)
  end

  it 'carries ties forward to the next rule' do
    rules = [
      fake_rule([ranking(loc_a, 0),   ranking(loc_b, 0),   ranking(loc_c, 1)]),   # A & B tie
      fake_rule([ranking(loc_a, 5),   ranking(loc_b, 1),   ranking(loc_c, 0)])    # B beats A in tied set
    ]

    expect(described_class.new(rules, order: order).pick(locations)).to eq(loc_b)
  end

  it 'falls back to the default location when rules tie all the way through' do
    rules = [
      fake_rule([ranking(loc_a, 0),   ranking(loc_b, 0),   ranking(loc_c, 0)])    # all tie
    ]

    expect(described_class.new(rules, order: order).pick(locations)).to eq(loc_a)  # loc_a is default
  end

  it 'falls back to default when there are no rules at all' do
    expect(described_class.new([], order: order).pick(locations)).to eq(loc_a)
  end

  it 'ignores abstaining (nil) rankings' do
    rules = [
      fake_rule([ranking(loc_a, nil), ranking(loc_b, nil), ranking(loc_c, 0)])    # only C ranked
    ]

    expect(described_class.new(rules, order: order).pick(locations)).to eq(loc_c)
  end
end
