require 'spec_helper'

RSpec.describe SpreeAvalara::Integration do
  subject(:integration) { build(:avalara_integration) }

  it 'registers as a tax integration' do
    expect(Spree.integrations).to include('SpreeAvalara::Integration')
    expect(described_class.integration_group).to eq('tax')
    expect(described_class.integration_name).to eq('Avalara AvaTax')
    # Wire shorthand comes from the outer module, and has to match the
    # provider_id stamped on this gem's tax lines.
    expect(described_class.api_type).to eq(SpreeAvalara::PROVIDER_ID)
  end

  it 'declares gallery metadata' do
    expect(described_class.logo_url).to start_with('https://')
    # The gem's locale file wins over the class fallback.
    expect(described_class.human_description).to include('file every order against the same transaction')
  end

  describe 'preferences' do
    it 'carries the same set as the legacy extension, so upgraded rows keep working' do
      expect(described_class.preference_schema.map { |field| field[:key] }).to contain_exactly(
        :account_number, :license_key, :endpoint, :company_code,
        :address_validation_enabled, :commit_transaction_enabled, :show_rate_in_label
      )
    end

    it 'starts a new connection against the sandbox' do
      fresh = described_class.new

      expect(fresh.preferred_endpoint).to eq(described_class::SANDBOX_ENDPOINT)
      expect(fresh.preferred_commit_transaction_enabled).to be(true)
      expect(fresh.preferred_address_validation_enabled).to be(false)
      expect(fresh.preferred_show_rate_in_label).to be(false)
    end

    it 'masks the license key' do
      expect(described_class.password_preference_keys).to include(:license_key)
    end
  end

  describe 'validations' do
    it 'requires the account number' do
      integration.preferred_account_number = nil

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_account_number]).to be_present
    end

    it 'requires the license key' do
      integration.preferred_license_key = nil

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_license_key]).to be_present
    end

    # Every document is filed against a company, so a blank code fails at the
    # first estimate rather than at save.
    it 'requires the company code' do
      integration.preferred_company_code = nil

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_company_code]).to be_present
    end

    # The dashboard picker offers two hosts, but the admin API takes a free-form
    # preferences hash — so without this an admin could point the client, and the
    # credentials, at any host they liked and read the reply back through the
    # connection test.
    it 'refuses an endpoint that is not one of Avalara own hosts' do
      integration = build(:avalara_integration, preferred_endpoint: 'http://169.254.169.254/latest/meta-data')

      expect(integration).not_to be_valid
      expect(integration.errors[:preferred_endpoint]).to be_present
    end

    it 'accepts either host Avalara publishes' do
      [described_class::SANDBOX_ENDPOINT, described_class::PRODUCTION_ENDPOINT].each do |endpoint|
        expect(build(:avalara_integration, preferred_endpoint: endpoint)).to be_valid
      end
    end
  end

  # Avalara publishes these two and no others, under these names — the same
  # choice the legacy extension offered, so nobody has to type a hostname.
  it 'offers the two Avalara hosts by name' do
    field = described_class.serialized_preference_schema.find { |entry| entry[:key] == :endpoint }

    expect(field[:options]).to eq([{ value: described_class::SANDBOX_ENDPOINT, label: 'Sandbox' },
                                   { value: described_class::PRODUCTION_ENDPOINT, label: 'Production' }])
  end

  describe '#can_connect?' do
    let(:client) { instance_double(SpreeAvalara::Client) }

    before { allow(integration).to receive(:client).and_return(client) }

    it 'is true when AvaTax reports the credentials authenticate' do
      allow(client).to receive(:ping).and_return('authenticated' => true, 'version' => '26.7.0')

      expect(integration.can_connect?).to be(true)
      expect(integration.connection_error_message).to be_nil
    end

    # A rejected key still answers 200, so a successful response has to be read.
    it 'reports invalid credentials when AvaTax answers but does not authenticate' do
      allow(client).to receive(:ping).and_return('authenticated' => false)

      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to eq('Invalid credentials')
    end

    it 'passes on the reason Avalara gave' do
      allow(client).to receive(:ping).and_raise(
        SpreeAvalara::RequestError.new('Authentication Incomplete.', status: 401,
                                       details: { 'message' => 'Authentication Incomplete.' })
      )

      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to eq('Authentication Incomplete.')
    end

    it 'falls back to a generic message when Avalara refuses without explaining' do
      allow(client).to receive(:ping).and_raise(
        SpreeAvalara::RequestError.new('AvaTax request failed with status 500', status: 500)
      )

      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to eq('Could not connect to AvaTax')
    end

    it 'falls back to a generic message on a response it cannot read' do
      allow(client).to receive(:ping).and_return('<html>Bad Gateway</html>')

      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to eq('Could not connect to AvaTax')
    end

    # Nothing answered, so the network error is the only actionable detail.
    it 'surfaces the transport failure when AvaTax is unreachable' do
      allow(client).to receive(:ping).and_raise(
        SpreeAvalara::RequestError.new('connection refused', status: nil)
      )

      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to eq('connection refused')
    end

    it 'surfaces an unexpected failure rather than raising into a save' do
      allow(client).to receive(:ping).and_raise(ArgumentError, 'endpoint is not a URL')

      expect(integration.can_connect?).to be(false)
      expect(integration.connection_error_message).to eq('endpoint is not a URL')
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

  describe '.active_for' do
    it 'finds the store\'s connected integration' do
      connected = create(:avalara_integration, :active, store: @default_store)

      expect(described_class.active_for(@default_store)).to eq(connected)
    end

    it 'ignores credentials that are on file but not connected' do
      create(:avalara_integration, store: @default_store)

      expect(described_class.active_for(@default_store)).to be_nil
    end

    it 'has no opinion without a store' do
      expect(described_class.active_for(nil)).to be_nil
    end
  end

  describe '.active_for!' do
    it 'returns the connected integration' do
      connected = create(:avalara_integration, :active, store: @default_store)

      expect(described_class.active_for!(@default_store)).to eq(connected)
    end

    # Fail closed: a market pointing at Avalara with nothing connected must not
    # quietly calculate no tax.
    it 'raises when the store has none' do
      expect { described_class.active_for!(@default_store) }.to raise_error(SpreeAvalara::NotConfiguredError)
    end
  end

  # What the dashboard's integrations gallery renders the card and its
  # credential form from.
  describe 'admin discovery' do
    subject(:entry) { Spree::Integration.discovery_entries.detect { |candidate| candidate[:type] == 'avalara' } }

    it 'describes the card' do
      expect(entry[:name]).to eq('Avalara AvaTax')
      expect(entry[:group]).to eq('tax')
      expect(entry[:logo_url]).to be_present
      expect(entry[:description]).to be_present
    end

    it 'describes the credential form without leaking the secret default' do
      license_key = entry[:preference_schema].detect { |field| field[:key] == :license_key }

      expect(entry[:preference_schema].size).to eq(7)
      expect(license_key[:type]).to eq(:password)
      expect(license_key[:default]).to be_nil
    end
  end
end
