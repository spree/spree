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

  describe 'errors' do
    it 'carries the AvaTax status and details on a request failure' do
      error = described_class::RequestError.new('boom', status: 401, details: { 'code' => 'AuthenticationIncomplete' })

      expect(error).to be_a(described_class::Error)
      expect(error.message).to eq('boom')
      expect(error.status).to eq(401)
      expect(error.details).to eq('code' => 'AuthenticationIncomplete')
    end

    it 'treats a missing integration as one of its own errors' do
      expect(described_class::NotConfiguredError.new).to be_a(described_class::Error)
    end
  end
end
