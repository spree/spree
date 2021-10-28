require 'spec_helper'

module Spree
  describe Payments::Create do
    subject { described_class }

    let(:store) { create(:store) }
    let(:order) { create(:order_with_totals, store: store, user: nil, email: 'john@snow.org') }

    let(:execute) { subject.call(order: order, params: params) }
    let(:value) { execute.value }

    let(:params) do
      {
        payment_method_id: payment_method.id,
        amount: order.total,
        source_attributes: {
          gateway_payment_profile_id: '12345',
          cc_type: 'visa',
          last_digits: '1111',
          name: 'John',
          month: '12',
          year: '2021'
        }
      }
    end

    let!(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
    let(:payment_source) { payment_method.payment_source_class.last }
    let(:payment) { order.payments.last }

    context 'valid attributes' do
      shared_context 'creates a payment' do
        it 'creates new payment record' do
          expect { execute }.to change(order.payments, :count).by(1)
          expect(payment.payment_method).to eq(payment_method)
        end
      end

      shared_context 'creates a payment source' do
        it 'creates new payment source record' do
          expect { execute }.to change(payment_method.payment_source_class, :count).by(1)
          expect(payment.payment_source).to eq(payment_source)
        end
      end

      context 'with new source attributes' do
        include_context 'creates a payment'
        include_context 'creates a payment source'

        context 'with user' do
          let(:user) { create(:user) }
          let(:order) { create(:order_with_totals, store: store, user: user) }

          include_context 'creates a payment'
          include_context 'creates a payment source'

          context 'assigns user' do
            before { execute }

            it { expect(payment_source.user).to eq(user) }
          end
        end
      end

      context 'with existing source' do
        let(:payment_source) { create(:credit_card, payment_method: payment_method) }
        let(:params) do
          {
            payment_method_id: payment_method.id,
            amount: order.total,
            source_id: payment_source.id
          }
        end

        include_context 'creates a payment'

        it { expect { execute }.not_to change(payment_method.payment_source_class, :count) }
      end

      context 'without source' do

      end
    end

    context 'missing payment method' do

    end

    context 'invalid attributes' do

    end
  end
end
