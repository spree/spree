require 'spec_helper'

module Spree
  describe Orders::WithdrawPaymentRequest do
    let(:store) { @default_store }
    let(:draft) { create(:order_with_line_items, store: store) }

    it 'is the registered order_withdraw_payment_request_workflow' do
      expect(Spree.order_withdraw_payment_request_workflow).to eq(described_class)
    end

    it 'takes the draft back out of the storefront' do
      draft.update_columns(payment_requested_at: 1.hour.ago)

      result = described_class.call(order: draft)

      expect(result).to be_success
      expect(draft.reload.payment_requested_at).to be_nil
      expect(draft).not_to be_payable_draft
    end

    it 'cancels the payment sessions the buyer opened', :job do
      draft.update_columns(payment_requested_at: 1.hour.ago)
      create(:bogus_payment_session, order: draft)

      expect { described_class.call(order: draft) }.
        to have_enqueued_job(Spree::Payments::CancelUnusedSessionsJob).with(draft.id)
    end

    it 'leaves a draft that was never requested as it is' do
      result = described_class.call(order: draft)

      expect(result).to be_success
      expect(draft.reload.payment_requested_at).to be_nil
    end

    it 'refuses a placed order' do
      order = create(:completed_order_with_totals, store: store)

      expect(described_class.call(order: order)).to be_failure
    end
  end
end
