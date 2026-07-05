require 'spec_helper'

# Integration scenarios for the default routing strategy. Per-rule semantics
# live in spec/models/spree/order_routing/rules/*. Reducer mechanics live in
# spec/models/spree/order_routing/strategy/reducer_spec.rb. This file just
# verifies the strategy plumbs them together end-to-end.
RSpec.describe Spree::OrderRouting::Strategy::Rules, type: :model do
  let(:store) { @default_store }
  let(:variant) { create(:variant) }

  let!(:default_loc)   { create(:stock_location, name: 'Default',   default: true) }
  let!(:preferred_loc) { create(:stock_location, name: 'Preferred', default: false) }

  let(:order) do
    create(:order_with_line_items, store: store, line_items_attributes: [{ variant: variant, quantity: 1 }])
  end

  before do
    [default_loc, preferred_loc].each do |loc|
      loc.stock_item_or_create(variant).update!(count_on_hand: 10)
    end
  end

  subject { described_class.new(order: order) }

  describe '#for_allocation (rules engaged)' do
    it 'routes to the default location when no preference is set' do
      packages = subject.for_allocation
      expect(packages.map(&:stock_location)).to all(eq(default_loc))
    end

    it 'routes to the preferred location when set on the order' do
      order.update!(preferred_stock_location: preferred_loc)

      packages = subject.for_allocation
      expect(packages.map(&:stock_location)).to all(eq(preferred_loc))
    end

    it 'resolves the reducer from the strategy namespace' do
      stub_const(
        "#{described_class}::Reducer",
        Class.new do
          def initialize(*); end

          def rank_all(*)
            raise 'nested reducer should not be used'
          end
        end
      )

      packages = subject.for_allocation
      expect(packages.map(&:stock_location)).to all(eq(default_loc))
    end
  end
end
