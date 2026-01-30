require 'spec_helper'

RSpec.describe Spree::Admin::Orders::PaymentLinksController, type: :controller do
  stub_authorization!
  render_views

  let(:order) { create(:order_with_line_items, state: 'payment') }

  describe 'POST #create' do
    subject { post :create, params: { order_id: order.to_param } }

    context 'when frontend is available' do
      let(:payment_url) { "http://shop.com/checkout/#{order.token}/payment" }

      before do
        allow(Spree::Core::Engine).to receive(:frontend_available?).and_return(true)
        allow(spree).to receive(:checkout_state_url).and_return(payment_url)
      end

      it 'sends a payment link email' do
        expect {
          subject
          perform_enqueued_jobs(except: Spree::Addresses::GeocodeAddressJob)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(flash[:success]).to eq(Spree.t('admin.orders.payment_link_sent'))
        expect(response).to redirect_to(spree.edit_admin_order_path(order))

        expect(ActionMailer::Base.deliveries.last.body).to include(payment_url)
      end
    end

    context 'when frontend is not available' do
      before do
        allow(Spree::Core::Engine).to receive(:frontend_available?).and_return(false)
      end

      it 'redirects to the order edit page' do
        subject
        expect(response).to redirect_to(spree.edit_admin_order_path(order))
      end
    end
  end
end
