require 'spec_helper'

module Spree
  describe Variants::RemoveLineItemJob, :job do
    let!(:order) { create(:order_with_line_items) }
    let!(:line_item) { order.line_items.take }
    let(:remove_line_item_service_double) { double('RemoveLineItemService') }

    it 'calls the cart_remove_item_service service' do
      expect(Spree::Dependencies.cart_remove_line_item_service).to receive(:constantize).and_return(remove_line_item_service_double)
      expect(remove_line_item_service_double).to receive(:call).with(order: order, line_item: line_item)

      described_class.perform_now(line_item: line_item)
    end
  end
end

