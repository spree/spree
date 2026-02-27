require 'spec_helper'

RSpec.describe Spree::Api::V3::PaymentSerializer do
  let(:store) { @default_store }
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(payment, params: base_params).to_h }

  describe 'serialized attributes' do
    let(:payment) { create(:payment) }

    it 'includes standard attributes' do
      expect(subject).to include(
        'id' => payment.prefixed_id,
        'state' => 'checkout',
        'number' => payment.number,
        'response_code' => '12345'
      )
      expect(subject['amount']).to be_present
    end

    it 'includes prefixed payment_method_id' do
      expect(subject['payment_method_id']).to eq(payment.payment_method.prefixed_id)
    end

    it 'includes display_amount' do
      expect(subject['display_amount']).to be_present
    end

    it 'includes timestamp attributes' do
      expect(subject).to have_key('created_at')
      expect(subject).to have_key('updated_at')
    end

    it 'includes payment_method association' do
      expect(subject['payment_method']).to be_a(Hash)
      expect(subject['payment_method']['id']).to eq(payment.payment_method.prefixed_id)
    end
  end

  describe 'source serialization' do
    context 'with credit card source' do
      let(:payment) { create(:payment) }

      it 'returns credit_card as source_type' do
        expect(subject['source_type']).to eq('credit_card')
      end

      it 'returns prefixed source_id' do
        expect(subject['source_id']).to eq(payment.source.prefixed_id)
      end

      it 'serializes the credit card source' do
        expect(subject['source']).to be_a(Hash)
        expect(subject['source']['id']).to eq(payment.source.prefixed_id)
        expect(subject['source']).to have_key('cc_type')
        expect(subject['source']).to have_key('last_digits')
        expect(subject['source']).to have_key('month')
        expect(subject['source']).to have_key('year')
        expect(subject['source']).to have_key('name')
      end
    end

    context 'with payment source (non-credit card)' do
      let(:payment) { create(:custom_payment) }

      it 'returns payment_source as source_type' do
        expect(subject['source_type']).to eq('payment_source')
      end

      it 'returns prefixed source_id' do
        expect(subject['source_id']).to eq(payment.source.prefixed_id)
      end

      it 'serializes the payment source' do
        expect(subject['source']).to be_a(Hash)
        expect(subject['source']['id']).to eq(payment.source.prefixed_id)
        expect(subject['source']).to have_key('gateway_payment_profile_id')
        expect(subject['source']).not_to have_key('public_metadata')
      end
    end

    context 'with store credit source' do
      let(:payment) { create(:store_credit_payment) }

      it 'returns store_credit as source_type' do
        expect(subject['source_type']).to eq('store_credit')
      end

      it 'returns prefixed source_id' do
        expect(subject['source_id']).to eq(payment.source.prefixed_id)
      end

      it 'serializes the store credit source' do
        expect(subject['source']).to be_a(Hash)
        expect(subject['source']['id']).to eq(payment.source.prefixed_id)
        expect(subject['source']).to have_key('amount_remaining')
        expect(subject['source']).to have_key('display_amount_remaining')
        expect(subject['source']).to have_key('currency')
      end
    end

    context 'without source (e.g. check payment)' do
      let(:payment) { create(:check_payment) }

      it 'returns nil for source_type' do
        expect(subject['source_type']).to be_nil
      end

      it 'returns nil for source_id' do
        expect(subject['source_id']).to be_nil
      end

      it 'returns nil for source' do
        expect(subject['source']).to be_nil
      end
    end
  end
end
