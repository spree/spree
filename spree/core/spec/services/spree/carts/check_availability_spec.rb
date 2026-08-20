require 'spec_helper'

RSpec.describe Spree::Carts::CheckAvailability do
  let(:store) { @default_store }
  let(:cart) { create(:cart, store: store) }
  let(:stock_location) { create(:stock_location, store: store) }
  let(:variant) { create(:variant) }

  before do
    variant.stock_levels.destroy_all
    create(:stock_level, variant: variant, stock_location: stock_location,
                        count_on_hand: 5, backorderable: false, adjust_count_on_hand: false)
    variant.stock_levels.reload
  end

  let(:external_provider_class) do
    Class.new(Spree::InventoryProvider::Base) do
      class << self
        attr_accessor :count, :fail_with
      end
      self.count = 2

      def self.key = 'wms'

      def stock_levels_for(variant, stock_location: nil)
        raise self.class.fail_with if self.class.fail_with

        [Spree::StockLevel.new(variant: variant, stock_location: variant.stock_levels.first&.stock_location,
                              count_on_hand: self.class.count, backorderable: false)]
      end
    end
  end

  describe 'with Spree own stock records' do
    it 'reports nothing unsupplyable when there is enough' do
      result = described_class.call(cart: cart, items: [{ variant: variant, quantity: 5 }])

      expect(result).to be_success
      expect(result.value).to be_empty
    end

    it 'reports the item when more is asked for than exists' do
      result = described_class.call(cart: cart, items: [{ variant: variant, quantity: 6 }])

      expect(result.value.map(&:first)).to eq([variant])
    end
  end

  describe 'with an external warehouse' do
    before do
      stub_const('SpreeTest::WmsProvider', external_provider_class)
      external_provider_class.fail_with = nil
      external_provider_class.count = 2
      Spree.inventory_providers << external_provider_class
      stub_store_preferences(store, inventory_provider: 'wms')
    end

    after { Spree.inventory_providers.delete(external_provider_class) }

    it 'believes the warehouse over the local snapshot' do
      result = described_class.call(cart: cart, items: [{ variant: variant, quantity: 4 }])

      expect(result.value.map(&:first)).to eq([variant])
    end

    it 'allows what the warehouse says it has' do
      result = described_class.call(cart: cart, items: [{ variant: variant, quantity: 2 }])

      expect(result.value).to be_empty
    end

    # Default policy: an oversell is recoverable, a blocked checkout is not.
    it 'sells on the local figure when the warehouse is unreachable' do
      external_provider_class.fail_with = Timeout::Error

      result = described_class.call(cart: cart, items: [{ variant: variant, quantity: 5 }])

      expect(result).to be_success
      expect(result.value).to be_empty
    end

    it 'refuses when the store would rather not sell than guess' do
      external_provider_class.fail_with = Timeout::Error
      stub_store_preferences(store, inventory_provider: 'wms', inventory_provider_failure_policy: 'strict')

      result = described_class.call(cart: cart, items: [{ variant: variant, quantity: 5 }])

      expect(result).to be_failure
    end
  end
end
