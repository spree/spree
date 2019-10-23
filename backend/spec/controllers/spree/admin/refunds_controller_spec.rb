require 'spec_helper'

describe Spree::Admin::RefundsController do
  stub_authorization!

  describe 'POST create' do
    context 'a Spree::Core::GatewayError is raised' do
      subject do
        post :create, params: {
                   refund: { amount: '50.0', refund_reason_id: '1' },
                   order_id: payment.order.to_param,
                   payment_id: payment.to_param
                 }
      end

      let(:payment) { create(:payment) }

      before do
        def controller.create
          raise Spree::Core::GatewayError, 'An error has occurred'
        end
      end

      it 'sets an error message with the correct text' do
        subject
        expect(flash[:error]).to eq 'An error has occurred'
      end

      it { is_expected.to render_template(:new) }
    end
  end
end
