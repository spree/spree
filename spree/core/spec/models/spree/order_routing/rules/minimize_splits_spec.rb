require 'spec_helper'

RSpec.describe Spree::OrderRouting::Rules::MinimizeSplits, type: :model do
  let(:store) { @default_store }

  let(:variant_a) { create(:variant) }
  let(:variant_b) { create(:variant) }
  let(:order) do
    build(:order, store: store).tap do |o|
      o.line_items << build(:line_item, variant: variant_a, quantity: 1, order: o)
      o.line_items << build(:line_item, variant: variant_b, quantity: 1, order: o)
    end
  end

  let(:full_coverage) { create(:stock_location) }
  let(:half_coverage) { create(:stock_location) }

  before do
    full_coverage.stock_item_or_create(variant_a).update!(count_on_hand: 10)
    full_coverage.stock_item_or_create(variant_b).update!(count_on_hand: 10)
    half_coverage.stock_item_or_create(variant_a).update!(count_on_hand: 10)
    # variant_b: no stock item / 0 count at half_coverage so coverage is 1.
  end

  subject(:rule) { described_class.new(store: store, position: 1) }

  it 'ranks higher-coverage locations lower (better)' do
    rankings = rule.rank(order, [full_coverage, half_coverage])

    full_rank = rankings.find { |r| r.location == full_coverage }.rank
    half_rank = rankings.find { |r| r.location == half_coverage }.rank

    expect(full_rank).to be < half_rank
    expect(full_rank).to eq(-2)  # negative coverage
    expect(half_rank).to eq(-1)
  end
end
