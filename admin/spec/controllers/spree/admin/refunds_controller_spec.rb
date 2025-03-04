require 'spec_helper'

describe Spree::Admin::RefundsController, type: :controller do
  stub_authorization!
  render_views

  let(:user) { create(:admin_user) }

  before do
    allow(controller).to receive(:current_ability).and_return(Spree::Dependencies.ability_class.constantize.new(user))
  end

  describe '#create' do
    context 'when successful' do
      subject do
        post :create, params: {
          refund: { amount: amount.to_s, refund_reason_id: refund_reason.id.to_s },
          order_id: payment.order.to_param,
          payment_id: payment.to_param
        }
      end

      let!(:refund_reason) { create(:refund_reason) }
      let(:payment) { create(:payment, amount: payment_amount, order: create(:completed_order_with_totals)) }
      let(:payment_amount) { amount * 2 }
      let(:amount) { 10.0 }
      let(:amount_in_cents) { amount * 100 }
      let(:authorization) { generate(:refund_transaction_id) }

      it 'creates refund' do
        expect { subject }.to change { Spree::Refund.count }.from(0).to(1)
      end

      it 'assigns refunder to created refund' do
        subject

        expect(payment.refunds.last.refunder).to eq user
      end
    end
  end
end
