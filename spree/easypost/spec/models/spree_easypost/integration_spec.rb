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

  it 'declares gallery metadata' do
    expect(described_class.logo_url).to start_with('https://')
    # The gem's locale file wins over the class fallback.
    expect(described_class.localized_description).to include('negotiated carrier contracts')
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

  # Real client, HTTP played back from spec/vcr — exercises the SDK request
  # path the stubs above bypass. Re-record with EASYPOST_TEST_API_KEY set.
  describe 'API contract (VCR)' do
    subject(:integration) do
      described_class.new(store: @default_store,
                          preferences: { api_key: ENV.fetch('EASYPOST_TEST_API_KEY', 'EZTK-recorded') })
    end

    it 'connects with a valid key' do
      VCR.use_cassette('carrier_accounts') do
        expect(integration.can_connect?).to be(true)
      end
    end

    it 'captures the vendor message on a rejected key' do
      VCR.use_cassette('carrier_accounts_unauthorized') do
        expect(integration.can_connect?).to be(false)
        expect(integration.connection_error_message).to be_present
      end
    end
  end

  describe 'verify before activate' do
    it 'blocks activation when the connection fails' do
      allow(integration).to receive(:can_connect?).and_return(false)
      integration.active = true

      expect(integration).not_to be_valid
      expect(integration.errors[:base]).to be_present
    end
  end
end
