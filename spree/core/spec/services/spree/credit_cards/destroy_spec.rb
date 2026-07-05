require 'spec_helper'

describe Spree::CreditCards::Destroy, type: :service do
  subject { described_class.call(card: credit_card) }

  let!(:order) { create(:order_with_line_items) }
  let!(:credit_card) { create(:credit_card, user_id: order.user_id) }

  before do
    allow(Spree::Deprecation).to receive(:warn)
  end

  describe '#call' do
    it 'emits a deprecation warning' do
      subject

      expect(Spree::Deprecation).to have_received(:warn).with(/deprecated and will be removed in Spree 6.0/, anything)
    end

    it 'still destroys the credit card' do
      subject

      expect(credit_card.reload.deleted_at).not_to be_nil
    end

    context 'with payments on incomplete orders' do
      let!(:payment) { create(:payment, source: credit_card, order: order) }
      let!(:complete_payment) { create(:payment, source: credit_card, order: order, state: 'completed') }

      it 'cleans up payments via the before_destroy callback' do
        res = subject

        expect(res.success).to eq true
        expect(payment.reload.state).to eq 'invalid'
        expect(complete_payment.reload.state).to eq 'void'
        expect(credit_card.deleted_at).not_to be_nil
      end
    end
  end
end
