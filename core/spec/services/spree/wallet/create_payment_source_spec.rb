require 'spec_helper'

module Spree
  describe Wallet::CreatePaymentSource do
    subject { described_class }

    let(:payment_method) { create(:credit_card_payment_method) }
    let(:payment_source) { payment_method.payment_source_class.last }
    let(:result) { subject.call(payment_method: payment_method, source_attributes: source_attributes)}

    let(:source_attributes) do
      {
        gateway_payment_profile_id: '12345',
        cc_type: 'visa',
        last_digits: '1111',
        name: 'John',
        month: '12',
        year: '2021'
      }
    end

    context 'valid params' do
      it 'creates a new payment source' do
        expect { result }.to change { payment_method.payment_source_class.count }.by(1)

        expect(payment_source.gateway_payment_profile_id).to eq('12345')
        expect(payment_source.cc_type).to eq('visa')
        expect(payment_source.last_digits).to eq('1111')
        expect(payment_source.name).to eq('John')
        expect(payment_source.month).to eq(12)
        expect(payment_source.year).to eq(2021)
      end

      it { expect(result.success?).to eq(true) }
      it { expect(result.value).to be_a(payment_method.payment_source_class) }

      context 'with user' do
        let(:user) { create(:user) }

        it 'assigns user to payment source' do
          expect {
            subject.call(payment_method: payment_method, source_attributes: source_attributes, user: user)
          }.to change { payment_method.payment_source_class.count }.by(1)

          expect(payment_source.user).to eq(user)
        end
      end
    end

    context 'missing payment method' do
      let(:payment_method) { nil }

      it { expect(result.success?).to eq(false) }
      it { expect(result.error.value).to eq(:payment_method_not_found) }
      it { expect(result.value).to eq(nil) }
    end

    context 'invalid attributes' do
      let(:source_attributes) do
        {
          gateway_payment_profile_id: ''
        }
      end

      it { expect(result.success?).to eq(false) }
      it { expect(result.error.value).to be_a(ActiveModel::Errors) }
    end
  end
end
