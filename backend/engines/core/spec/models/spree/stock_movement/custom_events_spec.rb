# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::StockMovement::CustomEvents do
  let(:stock_location) { create(:stock_location) }
  let(:product) { create(:product) }
  let(:variant) { product.master }
  let!(:stock_item) do
    item = variant.stock_items.first || create(:stock_item, variant: variant, stock_location: stock_location)
    item.update!(backorderable: false)
    item
  end

  before do
    allow(Spree::Events).to receive(:enabled?).and_return(true)
    allow(Spree::Events).to receive(:publish)
  end

  describe 'product.out_of_stock event' do
    before do
      stock_item.set_count_on_hand(10)
    end

    it 'publishes product.out_of_stock when product goes out of stock' do
      stock_item.stock_movements.create!(quantity: -10)

      expect(Spree::Events).to have_received(:publish).with('product.out_of_stock', anything, anything)
    end

    it 'does not publish when product still has stock' do
      stock_item.stock_movements.create!(quantity: -5)

      expect(Spree::Events).not_to have_received(:publish).with('product.out_of_stock', anything, anything)
    end

    it 'does not publish when product was already out of stock' do
      # Start with product already out of stock
      stock_item.set_count_on_hand(0)

      # Reset the mock to clear any events from setup
      RSpec::Mocks.space.proxy_for(Spree::Events).reset

      allow(Spree::Events).to receive(:enabled?).and_return(true)
      allow(Spree::Events).to receive(:publish)

      # Add some stock (this triggers back_in_stock, not out_of_stock)
      stock_item.stock_movements.create!(quantity: 1)

      expect(Spree::Events).not_to have_received(:publish).with('product.out_of_stock', anything, anything)
    end
  end

  describe 'product.back_in_stock event' do
    before do
      stock_item.set_count_on_hand(0)
    end

    it 'publishes product.back_in_stock when product comes back in stock' do
      stock_item.stock_movements.create!(quantity: 10)

      expect(Spree::Events).to have_received(:publish).with('product.back_in_stock', anything, anything)
    end

    it 'does not publish when product was already in stock' do
      stock_item.set_count_on_hand(5)

      stock_item.stock_movements.create!(quantity: 10)

      expect(Spree::Events).not_to have_received(:publish).with('product.back_in_stock', anything, anything)
    end
  end

  describe 'when events are disabled' do
    before do
      allow(Spree::Events).to receive(:enabled?).and_return(false)
      stock_item.set_count_on_hand(10)
    end

    it 'does not publish any events' do
      stock_item.stock_movements.create!(quantity: -10)

      expect(Spree::Events).not_to have_received(:publish).with('product.out_of_stock', anything, anything)
    end
  end
end
