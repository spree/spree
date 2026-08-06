require 'spec_helper'

RSpec.describe SpreeEasyPost::Integration do
  subject(:integration) do
    described_class.new(store: @default_store, preferences: { api_key: 'EZTK-test' })
  end

  it 'registers as a shipping integration' do
    expect(Spree.integrations).to include('SpreeEasyPost::Integration')
    expect(described_class.integration_group).to eq('shipping')
    expect(described_class.integration_name).to eq('EasyPost')
    # Wire shorthand comes from the outer module — SpreeEasyPost → easy_post.
    expect(described_class.api_type).to eq('easy_post')
  end

  it 'masks the api key as a password preference' do
    expect(described_class.password_preference_keys).to include(:api_key)
  end

  describe '#can_connect?' do
    let(:carrier_account_service) { double(all: []) }
    let(:client) { instance_double(EasyPost::Client, carrier_account: carrier_account_service) }

    before { allow(integration).to receive(:client).and_return(client) }

    it 'is true when an authenticated read succeeds' do
      expect(integration.can_connect?).to be(true)
    end

    it 'captures the vendor message on failure' do
      allow(carrier_account_service).to receive(:all).
        and_raise(EasyPost::Errors::EasyPostError.new('unauthorized'))

      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to eq('unauthorized')
    end
  end

  describe 'verify before activate' do
    it 'blocks activation when the connection fails' do
      allow(integration).to receive(:can_connect?).and_return(false)
      integration.active = true

      expect(integration).not_to be_valid
      expect(integration.errors[:active]).to be_present
    end
  end
end
