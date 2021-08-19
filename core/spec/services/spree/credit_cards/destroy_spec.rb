require 'spec_helper'

describe Spree::CreditCards::Destroy, type: :service do
  subject { described_class.call(card: credit_card) }

  let!(:order)  { create(:order_with_line_items) }
  let!(:credit_card)  { create(:credit_card, user_id: order.user_id) }

  describe '#call' do
    let!(:payment)          { create(:payment, source: credit_card, order: order) }
    let!(:complete_payment) { create(:payment, source: credit_card, order: order, state: 'completed') }

    it 'destroy credit_card and update payment state' do
      res = subject

      expect(res.success).to eq true
      expect(payment.reload.state).to eq 'invalid'
      expect(complete_payment.reload.state).to eq 'void'
      expect(credit_card.deleted_at).not_to be_nil
    end
  end

  describe '#invalidate_payments' do
    let!(:completed_order)        { create(:completed_order_with_pending_payment, user_id: order.user_id) }
    let!(:payment)                { create(:payment, source: credit_card, order: order) }
    let!(:complete_order_payment) { create(:payment, source: credit_card, order: completed_order, state: 'completed') }

    it 'destroy credit_card and invalidate valid checkout payments' do
      res = subject

      expect(res.success).to eq true
      expect(payment.reload.state).to eq 'invalid'
      expect(complete_order_payment.reload.state).to eq 'completed'
      expect(credit_card.deleted_at).not_to be_nil
    end
  end

  describe '#void_payments' do
    let!(:completed_payment)  { create(:payment, source: credit_card, order: order, state: 'completed') }
    let!(:processing_payment) { create(:payment, source: credit_card, order: order, state: 'processing') }
    let!(:pending_payment)    { create(:payment, source: credit_card, order: order, state: 'pending') }

    it 'destroy credit_card and void valid payments' do
      res = subject

      expect(res.success).to eq true
      expect(credit_card.deleted_at).not_to be_nil
      expect(completed_payment.reload.state).to eq 'void'
      expect(processing_payment.reload.state).to eq 'void'
      expect(pending_payment.reload.state).to eq 'void'
    end
  end

  describe '#destroy' do
    it 'remove credit_card' do
      expect(credit_card.deleted_at).to be_nil

      subject

      expect(credit_card.reload.deleted_at).not_to be_nil
    end
  end
end
