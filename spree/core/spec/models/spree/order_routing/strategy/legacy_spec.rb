require 'spec_helper'

# Strategy::Legacy delegates to Spree::Stock::Coordinator and therefore
# inherits its pre-routing behavior wholesale: every active location packed,
# Prioritizer's Adjuster distributes units across packages, no merchant
# routing rules consulted.
RSpec.describe Spree::OrderRouting::Strategy::Legacy, type: :model do
  let(:store) { @default_store }
  let(:variant_a) { create(:variant) }
  let(:variant_b) { create(:variant) }
  let!(:nyc) { create(:stock_location, name: 'NYC', default: true) }
  let!(:la)  { create(:stock_location, name: 'LA',  default: false) }

  let(:order) do
    o = create(:order, store: store, ship_address: create(:ship_address))
    create(:line_item, order: o, variant: variant_a, quantity: 1)
    create(:line_item, order: o, variant: variant_b, quantity: 1)
    o.reload
  end

  subject { described_class.new(order: order) }

  it 'splits the allocation across both locations when neither single one covers the cart' do
    nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
    la.stock_item_or_create(variant_b).update!(count_on_hand: 10)

    packages = subject.for_allocation
    location_ids = packages.map { |p| p.stock_location.id }

    expect(location_ids).to contain_exactly(nyc.id, la.id)
    expect(packages.flat_map(&:on_hand).size).to eq(2)
    expect(packages.flat_map(&:backordered)).to be_empty
  end

  it 'ignores OrderRoutingRule rows entirely' do
    # PreferredLocation rule would normally make `la` the winner; Legacy
    # should not consult it.
    Spree::OrderRouting::Rules::PreferredLocation
      .where(channel: order.channel).destroy_all
    Spree::OrderRouting::Rules::PreferredLocation.create!(
      store: store, channel: order.channel, position: 0
    )
    order.update!(preferred_stock_location: la)

    nyc.stock_item_or_create(variant_a).update!(count_on_hand: 10)
    nyc.stock_item_or_create(variant_b).update!(count_on_hand: 10)
    la.stock_item_or_create(variant_a).update!(count_on_hand: 10)
    la.stock_item_or_create(variant_b).update!(count_on_hand: 10)

    expect_any_instance_of(Spree::OrderRoutingRule).not_to receive(:rank)
    subject.for_allocation
  end

  describe 'lifecycle hooks' do
    it 'for_sale, for_release, for_cancellation are no-ops' do
      expect { subject.for_sale(fulfillment: nil) }.not_to raise_error
      expect { subject.for_release }.not_to raise_error
      expect { subject.for_cancellation }.not_to raise_error
    end
  end
end
