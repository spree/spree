require 'spec_helper'

module Spree
  describe Variants::RemoveFromIncompleteOrdersJob, :job do
    let!(:variant) { orders.first.line_items.first.variant }
    let!(:orders) { [create(:order_with_line_items)] }

    it 'enqueues the removal of variants line items' do
      expect { described_class.perform_later(variant) }.to(
        have_enqueued_job.on_queue('default')
      )
    end
  end
end
