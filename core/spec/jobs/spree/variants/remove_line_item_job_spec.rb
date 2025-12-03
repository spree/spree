require 'spec_helper'

module Spree
  describe Variants::RemoveLineItemJob, :job do
    let!(:order) { create(:order_with_line_items) }
    let!(:line_item) { order.line_items.take }

    it 'removes the line item from the order' do
      expect {
        described_class.perform_now(line_item: line_item)
      }.to change { order.reload.line_items.count }.by(-1)
    end
  end
end
