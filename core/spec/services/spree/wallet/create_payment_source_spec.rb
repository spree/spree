require 'spec_helper'

module Spree
  describe Wallet::CreatePaymentSource do
    subject { described_class }

    let(:store) { create(:store) }

    let(:execute) { subject.call(payment_method: payment_method, params: params) }
    let(:value) { execute.value }

    let(:params) do
      {
        gateway_payment_profile_id: '12345',
        cc_type: 'visa',
        last_digits: '1111',
        name: 'John',
        month: '12',
        year: '2021'
      }
    end

    let!(:payment_method) { create(:credit_card_payment_method, stores: [store]) }
    let(:payment_source) { payment_method.payment_source_class.last }

    context 'valid attributes' do
      shared_context 'creates a payment source' do
        before { execute }

        it 'creates new payment source record' do
          expect { change(payment_method.payment_source_class, :count).by(1) }
        end

        it 'returns newly created record in .value' do
          expect(execute.value).to be_kind_of(payment_method.payment_source_class)
        end

        it 'assigns payment method' do
          expect(payment_source.payment_method).to eq(payment_method)
        end
      end

      context 'with source attributes' do
        include_context 'creates a payment source'

        context 'with user' do
          let(:user) { create(:user) }
          let(:execute) { subject.call(payment_method: payment_method, params: params, user: user) }

          include_context 'creates a payment source'

          context 'assigns user' do
            before { execute }

            it { expect(payment_source.user).to eq(user) }
          end
        end
      end
    end

    context 'missing attributes' do
      let(:params) { nil }

      it { expect(execute.success?).to eq(false) }
      it { expect(execute.error.to_s).to eq('missing_attributes') }
    end

    context 'invalid attributes' do
      let(:params) do
        {
          gateway_payment_profile_id: '',
          cc_type: 'visa',
          last_digits: '',
          name: '',
          month: '',
          year: ''
        }
      end

      it { expect(execute.success?).to eq(false) }
      it { expect(execute.error.value).to be_kind_of(ActiveModel::Errors) }
    end
  end
end
