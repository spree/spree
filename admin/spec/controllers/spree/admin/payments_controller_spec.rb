require 'spec_helper'

RSpec.describe Spree::Admin::PaymentsController, type: :controller do
  stub_authorization!
  render_views

  let(:order) { create(:order_with_line_items, state: 'payment') }
  let(:payment_method) { create(:credit_card_payment_method, display_on: 'back_end') }

  describe 'PUT #capture' do
    subject { put :capture, params: params }
    let(:params) { { order_id: order.number, id: payment.id } }
    let(:payment) { create(:payment, order: order, payment_method: payment_method, amount: order.total) }

    it 'captures unprocessed payment' do
      subject

      expect(payment.reload.state).to eq('completed')
      expect(flash[:success]).to eq(Spree.t(:payment_updated))
      expect(response).to redirect_to(spree.edit_admin_order_path(order))
      expect(order.reload.state).to eq('complete')
    end

    context 'when something goes wrong' do
      it 'sets an error message and redirects back' do
        allow_any_instance_of(Spree::Payment).to receive(:capture!).and_raise(Spree::Core::GatewayError.new('An error occurred'))

        subject

        expect(flash[:error]).to eq('An error occurred')
        expect(payment.reload.state).to eq('checkout')
        expect(response).to redirect_to(spree.edit_admin_order_path(order))
        expect(order.reload.state).to eq('payment')
      end
    end
  end

  describe 'PUT #void' do
    subject { put :void, params: params }
    let(:params) { { order_id: order.number, id: payment.id } }
    let(:payment) { create(:payment, order: order, payment_method: payment_method, amount: order.total, state: 'completed') }

    it 'voids completed payment' do
      subject

      expect(payment.reload.state).to eq('void')
      expect(flash[:success]).to eq(Spree.t(:payment_updated))
      expect(response).to redirect_to(spree.edit_admin_order_path(order))
      expect(order.reload.state).to eq('payment')
    end

    context 'when something goes wrong' do
      it 'sets an error message and redirects back' do
        allow_any_instance_of(Spree::Payment).to receive(:void_transaction!).and_raise(Spree::Core::GatewayError.new('An error occurred'))

        subject

        expect(flash[:error]).to eq('An error occurred')
        expect(payment.reload.state).to eq('completed')
        expect(response).to redirect_to(spree.edit_admin_order_path(order))
        expect(order.reload.state).to eq('payment')
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: params }

    before do
      order.ship_address.update(user: order.user)
      order.bill_address.update(user: order.user)
    end

    context 'with invalid params' do
      let(:params) { { order_id: order.number, payment: { amount: order.total, payment_method_id: payment_method.id.to_s } } }

      it 'does not create a payment' do
        subject

        expect(order.payments.count).to eq(0)
        expect(response).to render_template(:new)
        expect(response.status).to eq(422)
        expect(order.reload.state).to eq('payment')
      end
    end

    context 'with a valid credit card' do
      let(:params) do
        {
          order_id: order.number,
          card: 'new',
          payment: {
            amount: order.total,
            payment_method_id: payment_method.id.to_s,
            source_attributes: {
              name: 'Test User',
              number: '4111 1111 1111 1111',
              expiry: "09 / #{Time.current.year + 1}",
              verification_value: '123'
            }
          }
        }
      end

      it 'processes payment correctly' do
        subject

        expect(order.payments.count).to eq(1)
        expect(response).to redirect_to(spree.edit_admin_order_path(order))
        expect(order.reload.state).to eq('complete')
      end
    end

    context 'with an invalid credit card' do
      let(:params) do
        {
          order_id: order.number,
          card: 'new',
          payment: {
            amount: order.total,
            payment_method_id: payment_method.id.to_s,
            source_attributes: {
              name: 'Test User',
              number: '4111 2111 1111 1111',
              expiry: "09 / #{Time.current.year + 1}",
              verification_value: '123'
            }
          }
        }
      end

      it 'set an flash message and stops at payment state' do
        subject

        expect(order.payments.count).to eq(1)
        expect(response).to render_template(:new)
        expect(response.status).to eq(422)
        expect(flash[:error]).to eq('Bogus Gateway: Forced failure')
        expect(order.reload.state).to eq('payment')
      end
    end

    context 'when billing address is missing' do
      before do
        order.update!(bill_address_id: nil)
      end

      let(:params) do
        {
          order_id: order.number,
          card: 'new',
          payment: {
            amount: order.total,
            payment_method_id: payment_method.id.to_s,
            source_attributes: {
              name: 'Test User',
              number: '4111 1111 1111 1111',
              expiry: "09 / #{Time.current.year + 1}",
              verification_value: '123'
            }
          }
        }
      end

      it 'copies shipping address to billing address' do
        subject

        expect(order.reload.state).to eq('complete')
        expect(order.reload.billing_address.reload).to eq(order.shipping_address)
        expect(order.payments.count).to eq(1)
        expect(response).to redirect_to(spree.edit_admin_order_path(order))
      end
    end
  end
end
