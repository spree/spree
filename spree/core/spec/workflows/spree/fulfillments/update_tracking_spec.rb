require 'spec_helper'

module Spree
  describe Fulfillments::UpdateTracking do
    subject { described_class }

    let(:fulfillment) { create(:order_ready_to_ship, store: @default_store).fulfillments.first }

    before { Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment) }

    it 'resolves the primary delivery for legacy callers, with a warning' do
      expect(Spree::Deprecation).to receive(:warn).with(/Deliveries::UpdateTracking/)

      result = subject.call(fulfillment: fulfillment, tracking_status: 'in_transit')

      expect(result).to be_success
      expect(fulfillment.primary_delivery.reload.status).to eq('in_transit')
    end

    it 'fails for a fulfillment with no delivery' do
      allow(Spree::Deprecation).to receive(:warn)
      fulfillment.deliveries.destroy_all

      expect(subject.call(fulfillment: fulfillment, tracking_status: 'in_transit')).to be_failure
    end
  end
end
