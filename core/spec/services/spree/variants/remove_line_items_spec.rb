require 'spec_helper'

module Spree
  describe Variants::RemoveLineItems do
    subject { described_class }

    describe '#call' do
      let(:variant) { create(:variant) }
      let(:orders) { create_list(:order_with_line_items, 3) }
      let(:execute) { subject.call(variant: variant) }
      let(:remove_item_service_double) { double('RemoveItemService') }

      before do
        orders.each { |order| order.line_items.take.update(variant: variant) }
      end

      it 'calls the cart_remove_item_service dependency for each order' do
        expect(Spree::Dependencies.cart_remove_item_service).to receive(:constantize).and_return(remove_item_service_double)
        expect(remove_item_service_double).to receive(:call).with(variant: variant, order: orders.first)
        expect(remove_item_service_double).to receive(:call).with(variant: variant, order: orders.second)
        expect(remove_item_service_double).to receive(:call).with(variant: variant, order: orders.third)

        execute
      end
    end
  end
end

