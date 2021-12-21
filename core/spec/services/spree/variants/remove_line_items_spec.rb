require 'spec_helper'

module Spree
  describe Variants::RemoveLineItems do
    subject { described_class }

    describe '#call' do
      let(:orders) { create_list(:order_with_line_items, 3) }
      let(:variant) { orders.first.line_items.first.variant }
      let(:execute) { subject.call(variant: variant, order_ids: orders.pluck(:id)) }
      let(:remove_item_service_double) { double('RemoveItemService') }

      it 'calls the cart_remove_item_service dependency for each order' do
        expect(Spree::Dependencies.cart_remove_item_service).to receive(:constantize).and_return(remove_item_service_double)
        expect(remove_item_service_double).to receive(:call).with(variant: variant, order: orders.first)

        expect(Spree::Dependencies.cart_remove_item_service).to receive(:constantize).and_return(remove_item_service_double)
        expect(remove_item_service_double).to receive(:call).with(variant: variant, order: orders.second)

        expect(Spree::Dependencies.cart_remove_item_service).to receive(:constantize).and_return(remove_item_service_double)
        expect(remove_item_service_double).to receive(:call).with(variant: variant, order: orders.third)

        execute
      end
    end
  end
end

