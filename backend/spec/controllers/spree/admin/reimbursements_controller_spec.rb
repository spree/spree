require 'spec_helper'

describe Spree::Admin::ReimbursementsController, :type => :controller do
  stub_authorization!

  let!(:default_refund_reason) do
    Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false)
  end

  describe '#create' do
    let(:customer_return)  { create(:customer_return, line_items_count: 1) }
    let(:order) { customer_return.order }
    let(:return_item) { customer_return.return_items.first }
    let(:payment) { order.payments.first }

    subject do
      spree_post :create, order_id: order.to_param, build_from_customer_return_id: customer_return.id
    end

    it 'creates the reimbursement' do
      expect { subject }.to change { order.reimbursements.count }.by(1)
      expect(assigns(:reimbursement).return_items.to_a).to eq customer_return.return_items.to_a
    end

    it 'redirects to the edit page' do
      subject
      expect(response).to redirect_to(spree.edit_admin_order_reimbursement_path(order, assigns(:reimbursement)))
    end
  end

  describe "#perform" do
    let(:reimbursement) { create(:reimbursement) }
    let(:customer_return) { reimbursement.customer_return }
    let(:order) { reimbursement.order }
    let(:return_items) { reimbursement.return_items }
    let(:payment) { order.payments.first }

    subject do
      spree_post :perform, order_id: order.to_param, id: reimbursement.to_param
    end

    it 'redirects to customer return page' do
      subject
      expect(response).to redirect_to spree.admin_order_reimbursement_path(order, reimbursement)
    end

    it 'performs the reimbursement' do
      expect {
        subject
      }.to change { payment.refunds.count }.by(1)
      expect(payment.refunds.last.amount).to be > 0
      expect(payment.refunds.last.amount).to eq return_items.to_a.sum(&:total)
    end

    context "a Spree::Core::GatewayError is raised" do
      before(:each) do
        def controller.perform
          raise Spree::Core::GatewayError.new('An error has occurred')
        end
      end

      it "sets an error message with the correct text" do
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
