require 'spec_helper'

describe Spree::Admin::RefundsController, type: :controller do
  stub_authorization!
  render_views

  let(:user) { create(:admin_user) }

  before do
    allow(controller).to receive(:current_ability).and_return(Spree.ability_class.new(user))
  end

  let(:order) { create(:completed_order_with_totals) }
  let(:payment) { create(:payment, amount: payment_amount, order: order) }
  let(:payment_amount) { amount * 2 }
  let(:amount) { 10.0 }

  describe '#create' do
    context 'when successful' do
      subject do
        post :create, params: {
          refund: { amount: amount.to_s, refund_reason_id: refund_reason.id.to_s },
          order_id: order.to_param,
          payment_id: payment.to_param
        }
      end

      let!(:refund_reason) { create(:refund_reason) }
      let(:amount_in_cents) { amount * 100 }
      let(:authorization) { generate(:refund_transaction_id) }

      it 'creates refund' do
        expect { subject }.to change { Spree::Refund.count }.from(0).to(1)

        expect(response).to redirect_to spree.edit_admin_order_path(payment.order)
      end

      it 'assigns refunder to created refund' do
        subject

        expect(payment.refunds.last.refunder).to eq admin_user
      end
    end
  end

  describe '#update' do
    subject { put :update, params: { id: refund.id, order_id: order.to_param, payment_id: payment.to_param, refund: { refund_reason_id: refund_reason.id.to_s } } }

    let(:refund) { create(:refund, amount: 10, payment: payment) }
    let(:refund_reason) { create(:refund_reason) }

    it 'updates the refund' do
      subject

      expect(response).to redirect_to spree.edit_admin_order_path(refund.payment.order)
    end
  end
end
