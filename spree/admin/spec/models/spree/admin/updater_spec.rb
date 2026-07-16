require 'spec_helper'

RSpec.describe Spree::Admin::Updater do
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:releases) do
    [{ 'name' => '9.9.9', 'tag_name' => 'v9.9.9', 'url' => 'https://github.com/spree/spree/releases/tag/v9.9.9' }]
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
  end

  def stub_spree_cloud(success: true, body: releases.to_json)
    http = instance_double(Net::HTTP, 'use_ssl=': nil, 'open_timeout=': nil, 'read_timeout=': nil)
    allow(Net::HTTP).to receive(:new).and_return(http)

    response = double('response', body: body)
    allow(response).to receive(:is_a?) { |klass| success && klass == Net::HTTPSuccess }
    allow(http).to receive(:get) do |uri|
      @requested_uri = uri
      response
    end

    http
  end

  describe '.fetch_updates' do
    it 'reports version, environment, storefront url and the anonymous install id' do
      stub_spree_cloud

      described_class.fetch_updates

      params = Rack::Utils.parse_query(@requested_uri.query)
      expect(params['version']).to eq(Spree.version)
      expect(params['environment']).to eq('test')
      expect(params['url']).to eq(Spree::Current.store.storefront_url)
      expect(params['install_id']).to eq(Spree.install_id)
    end

    it 'returns the parsed release list' do
      stub_spree_cloud

      expect(described_class.fetch_updates).to eq(releases)
      expect(described_class.update_available?).to be true
      expect(described_class.latest_release['name']).to eq('9.9.9')
    end

    it 'returns an empty list on a non-success response and caches it' do
      http = stub_spree_cloud(success: false, body: 'oops')

      expect(described_class.fetch_updates).to eq([])
      expect(described_class.update_available?).to be false
      expect(http).to have_received(:get).once
    end

    it 'returns an empty list and reports the error when the request raises' do
      http = stub_spree_cloud
      allow(http).to receive(:get).and_raise(Net::OpenTimeout)
      allow(Rails.error).to receive(:report)

      expect(described_class.fetch_updates).to eq([])
      expect(Rails.error).to have_received(:report).with(instance_of(Net::OpenTimeout))
    end
  end
end
