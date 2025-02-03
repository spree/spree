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

  describe 'GET #new' do
    subject { get :new, params: params }
    let(:params) { { order_id: order.number } }

    context 'when order can transition to payment state' do
      let(:order) { create(:order_ready_to_ship, state: 'delivery') }

      it 'transitions order to payment state' do
        expect(order.state).to eq('delivery')
        subject
        expect(order.reload.state).to eq('payment')
      end
    end

    context 'when specific payment method is requested' do
      let(:specific_payment_method) { create(:credit_card_payment_method, display_on: 'back_end') }
      let(:params) { { order_id: order.number, payment_method_id: specific_payment_method.id } }

      before do
        create(:credit_card_payment_method, display_on: 'back_end')
      end

      it 'assigns the requested payment method' do
        subject
        expect(assigns(:payment).payment_method).to eq(specific_payment_method)
      end
    end

    context 'when no specific payment method is requested' do
      let!(:first_payment_method) { create(:credit_card_payment_method, display_on: 'back_end') }

      before do
        create(:credit_card_payment_method, display_on: 'back_end')
      end

      it 'assigns the first available payment method' do
        subject
        expect(assigns(:payment).payment_method).to eq(first_payment_method)
      end
    end

    context 'when payment method requires source' do
      let(:payment_method) { create(:credit_card_payment_method, display_on: 'back_end') }
      let(:params) { { order_id: order.number, payment_method_id: payment_method.id } }

      it 'builds a new source' do
        subject
        expect(assigns(:payment).source).to be_a_new(Spree::CreditCard)
      end
    end

    context 'when payment method does not require source' do
      let(:payment_method) { create(:check_payment_method, display_on: 'back_end') }
      let(:params) { { order_id: order.number, payment_method_id: payment_method.id } }

      it 'does not build a source' do
        subject
        expect(assigns(:payment).source).to be_nil
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

        expect(order.reload.payments.count).to eq(1)
        expect(response).to redirect_to(spree.edit_admin_order_path(order))
        expect(order.state).to eq('complete')
      end
    end

    context 'with existing card' do
      let(:credit_card) { create(:credit_card, user: order.user, payment_method: payment_method, gateway_customer_profile_id: 'BGS-1234567890') }

      let(:params) do
        {
          order_id: order.number,
          payment: {
            amount: order.total,
            payment_method_id: payment_method.id.to_s,
            source_attributes: {
              id: credit_card.id
            }
          }
        }
      end

      it 'processes payment correctly' do
        subject

        expect(response).to redirect_to(spree.edit_admin_order_path(order))
        order.reload
        expect(order.payments.count).to eq(1)
        expect(order.payments.first.source).to eq(credit_card)
        expect(order.state).to eq('complete')
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
