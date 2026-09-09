require 'spec_helper'

RSpec.describe SpreeAvalara do
  it 'names itself consistently for tax rows and for Avalara' do
    expect(described_class::PROVIDER_ID).to eq('avalara')
    expect(described_class::APP_NAME).to be_present
    expect(described_class::APP_VERSION).to be_present
  end

  it 'loads as a Rails engine with its translations' do
    expect(described_class::Engine.root.join('config', 'locales', 'en.yml')).to exist
    expect(Spree.t('integrations.avalara.description')).to include('Avalara AvaTax')
  end

  describe 'timeouts' do
    around do |example|
      original = ENV.to_hash
      example.run
      ENV.replace(original)
    end

    it 'defaults to values a checkout can wait for' do
      expect(described_class.open_timeout).to eq(2.0)
      expect(described_class.read_timeout).to eq(6.0)
    end

    it 'takes deployment overrides from the environment' do
      ENV['SPREE_AVALARA_OPEN_TIMEOUT'] = '0.25'
      ENV['SPREE_AVALARA_READ_TIMEOUT'] = '1.5'

      expect(described_class.open_timeout).to eq(0.25)
      expect(described_class.read_timeout).to eq(1.5)
    end
  end

  # The browsing market and the tax destination diverge for mundane reasons, so
  # inclusiveness is resolved through the market covering the destination.
  describe '.tax_inclusive?' do
    let(:german_market) { instance_double(Spree::Market, tax_inclusive: true, country_codes: ['DE']) }
    let(:us_market) { instance_double(Spree::Market, tax_inclusive: false, country_codes: ['US']) }
    let(:store) { instance_double(Spree::Store, markets: [us_market, german_market]) }

    def owner(country:, market:)
      address = country && instance_double(Spree::Address, country_code: country)
      instance_double(Spree::Cart, tax_address: address, market: market, store: store)
    end

    it 'reads the cart market when there is no address to resolve from' do
      expect(described_class.tax_inclusive?(owner(country: nil, market: german_market))).to be(true)
    end

    # The well-behaved case: a German buyer on the German market, where this is
    # a no-op against the naive reading.
    it 'keeps the cart market when it covers the destination' do
      expect(described_class.tax_inclusive?(owner(country: 'DE', market: german_market))).to be(true)
    end

    # The 5.x bug: a currency switch left the market pointing elsewhere.
    it 'resolves through the store market covering the destination instead' do
      expect(described_class.tax_inclusive?(owner(country: 'DE', market: us_market))).to be(true)
      expect(described_class.tax_inclusive?(owner(country: 'US', market: german_market))).to be(false)
    end

    it 'falls back to the cart market when no market covers the destination' do
      expect(described_class.tax_inclusive?(owner(country: 'JP', market: german_market))).to be(true)
    end

    it 'is false rather than nil for a cart with no market at all' do
      expect(described_class.tax_inclusive?(owner(country: nil, market: nil))).to be(false)
    end
  end

  describe 'errors' do
    it 'carries the AvaTax status and details on a request failure' do
      error = described_class::RequestError.new('boom', status: 401, details: { 'code' => 'AuthenticationIncomplete' })

      # This gem's own class, not core's: whether a failure means "could not
      # ask" or "was told no" depends on the status, and TaxProvider decides
      # that at the contract boundary.
      expect(error).to be_a(described_class::Error)
      expect(error).not_to be_a(Spree::Tax::ProviderError)
      expect(error.message).to eq('boom')
      expect(error.status).to eq(401)
      expect(error.details).to eq('code' => 'AuthenticationIncomplete')
    end

    it 'treats a missing integration as one of its own errors' do
      expect(described_class::NotConfiguredError.new).to be_a(described_class::Error)
    end
  end
end
