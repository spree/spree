require 'spec_helper'

module Spree
  describe Orders::RequestPayment do
    let(:store) { @default_store }
    let(:draft) { create(:order_with_line_items, store: store) }

    it 'is the registered order_request_payment_workflow' do
      expect(Spree.order_request_payment_workflow).to eq(described_class)
    end

    it 'stamps the request, making the draft payable', :events do
      published = []
      allow(Spree::Events).to receive(:publish) { |name, *| published << name }

      result = described_class.call(order: draft)

      expect(result).to be_success
      expect(draft.reload.payment_requested_at).to be_present
      expect(draft).to be_payable_draft
      expect(published).to include('order.payment_requested')
    end

    # A merchant who re-priced the draft sends the request anew.
    it 're-stamps a draft already requested' do
      draft.update_columns(payment_requested_at: 2.days.ago)

      expect(described_class.call(order: draft)).to be_success
      expect(draft.reload.payment_requested_at).to be_within(1.minute).of(Time.current)
    end

    it 'refuses a placed order' do
      draft.update_columns(status: 'placed', completed_at: Time.current)

      result = described_class.call(order: draft)

      expect(result).to be_failure
      expect(draft.reload.payment_requested_at).to be_nil
    end

    it 'refuses the draft of a checkout in progress' do
      draft.update_columns(cart_id: create(:cart).id)

      expect(described_class.call(order: draft)).to be_failure
    end

    it 'refuses a draft a seller division left behind' do
      draft.update_columns(order_group_id: create(:order_group).id)

      expect(described_class.call(order: draft)).to be_failure
    end

    it 'lets an extension veto the request' do
      Spree.hooks.register('orders.request_payment.validate') { |workflow| workflow.reject!('quote not accepted') }

      result = described_class.call(order: draft)

      expect(result).to be_failure
      expect(draft.reload.payment_requested_at).to be_nil
    ensure
      Spree.hooks.unregister('orders.request_payment.validate')
    end
  end
end
