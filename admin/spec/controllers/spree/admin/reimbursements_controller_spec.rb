require 'spec_helper'

describe Spree::Admin::ReimbursementsController, type: :controller do
  stub_authorization!
  render_views

  let(:user) { create(:admin_user) }

  before do
    Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false)
  end

  describe '#create' do
    context 'when build_from_customer_return_id is present' do
      subject do
        post :create, params: { order_id: order.to_param, build_from_customer_return_id: customer_return.id }
      end

      let(:order) { create(:order) }
      let(:customer_return) { create(:customer_return) }


      it 'creates a reimbursement from a customer return' do
        expect do
          subject
        end.to change { Spree::Reimbursement.count }.by(1)
        expect(Spree::Reimbursement.last.customer_return).to eq(customer_return)
      end
    end
  end

  describe '#perform' do
    subject do
      post :perform, params: { order_id: order.to_param, id: reimbursement.to_param }
    end

    let(:reimbursement) { create(:reimbursement, performed_by: nil) }
    let(:customer_return) { reimbursement.customer_return }
    let(:order) { reimbursement.order }
    let(:return_items) { reimbursement.return_items }
    let(:payment) { order.payments.first }

    it 'redirects to customer return page' do
      subject
      expect(response).to redirect_to spree.admin_order_reimbursement_path(order, reimbursement)
    end

    it 'performs the reimbursement' do
      expect do
        subject
      end.to change { payment.refunds.count }.by(1)
      expect(payment.refunds.last.amount).to be > 0
      expect(payment.refunds.last.amount).to eq return_items.to_a.sum(&:total)
    end

    it 'assigns reimbursement performer' do
      expect { subject }.to change { reimbursement.reload.performed_by }.from(nil).to(admin_user)
    end

    context 'a Spree::Core::GatewayError is raised' do
      before do
        def controller.perform
          raise Spree::Core::GatewayError, 'An error has occurred'
        end
      end

      it 'sets an error message with the correct text' do
        subject
        expect(flash[:error]).to eq 'An error has occurred'
      end

      it 'redirects to the edit page' do
        subject
        redirect_path = spree.edit_admin_order_reimbursement_path(order, assigns(:reimbursement))
        expect(response).to redirect_to(redirect_path)
      end
    end
  end
end
