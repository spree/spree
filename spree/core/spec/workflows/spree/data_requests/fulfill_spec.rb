require 'spec_helper'

RSpec.describe Spree::DataRequests::Fulfill do
  let(:store) { @default_store }
  let(:customer) { create(:customer, email: 'buyer@example.com') }

  describe 'an access request' do
    let(:data_request) { create(:data_request, store: store, customer: customer) }

    subject(:result) { described_class.call(data_request: data_request) }

    it 'completes the request' do
      expect(result).to be_success
      expect(data_request.reload).to be_completed
      expect(data_request.completed_at).to be_present
    end

    it 'attaches the export' do
      result

      expect(data_request.reload.export_file).to be_attached
    end

    it 'writes the customer\'s data into the file' do
      result

      payload = JSON.parse(data_request.reload.export_file.download)

      expect(payload.dig('account', 'email')).to eq('buyer@example.com')
    end

    it 'sets an expiry so the copy does not sit around forever' do
      result

      expect(data_request.reload.expires_at).to be_present
    end

    it 'refuses a request that has already been processed' do
      described_class.call(data_request: data_request)

      expect(described_class.call(data_request: data_request.reload)).to be_failure
    end

    describe 'the payload hook' do
      let(:handler) { ->(_workflow) { { loyalty: { points: 120 } } } }

      before { Spree.hooks.register('data_requests.fulfill.extend_payload', handler) }
      after { Spree.hooks.unregister('data_requests.fulfill.extend_payload', handler) }

      it 'lets a host app add data Spree does not model' do
        result

        payload = JSON.parse(data_request.reload.export_file.download)

        expect(payload.dig('loyalty', 'points')).to eq(120)
      end

      it 'still includes what Spree knows' do
        result

        payload = JSON.parse(data_request.reload.export_file.download)

        expect(payload['account']).to be_present
      end
    end
  end

  describe 'an erasure request' do
    let(:data_request) { create(:data_request, :erasure, store: store, customer: customer) }

    it 'anonymizes the customer' do
      described_class.call(data_request: data_request)

      expect(customer.reload.anonymized_at).to be_present
      expect(customer.email).not_to eq('buyer@example.com')
    end

    it 'attaches no file' do
      described_class.call(data_request: data_request)

      expect(data_request.reload.export_file).not_to be_attached
    end

    it 'fails the request when the erasure is refused' do
      customer.update_columns(anonymized_at: Time.current)

      expect(described_class.call(data_request: data_request)).to be_failure
    end
  end
end
