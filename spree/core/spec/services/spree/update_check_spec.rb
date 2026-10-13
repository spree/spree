require 'spec_helper'

RSpec.describe Spree::UpdateCheck do
  let(:http) { instance_double(Net::HTTP) }
  let(:releases) do
    [
      { 'tag_name' => 'v99.0.0', 'url' => 'https://example.com/evil', 'published_at' => '2026-10-02T10:51:38Z' },
      { 'tag_name' => 'v99.1.0', 'published_at' => '2026-10-09T10:00:00Z' },
      { 'tag_name' => 'v5.0.0' },
      { 'tag_name' => '@spree/sdk@9.0.0' },
      'not a release'
    ]
  end
  let(:response) do
    Net::HTTPOK.new('1.1', '200', 'OK').tap { |ok| allow(ok).to receive(:body).and_return(releases.to_json) }
  end
  let(:requested_query) { Rack::Utils.parse_query(URI(@requested_path).query) }

  around do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = original
  end

  before do
    allow(Rails.env).to receive(:test?).and_return(false)
    with_env({})
    allow(Net::HTTP).to receive(:start).with('spreecloud.io', 443, hash_including(use_ssl: true, max_retries: 0, open_timeout: 1, read_timeout: 1)) { |*, **, &block| block.call(http) }
    allow(http).to receive(:get) { |path| @requested_path = path; response }
  end

  def with_env(values)
    allow(ENV).to receive(:[]).and_call_original
    { 'CI' => nil }.merge(values).each { |name, value| allow(ENV).to receive(:[]).with(name).and_return(value) }
  end

  describe '.status' do
    it 'sends the 5.x keys unchanged with the usage fields beside them' do
      described_class.status

      expect(requested_query).to include(
        'version' => Spree.version,
        'environment' => Rails.env,
        'url' => @default_store.storefront_url,
        'install_id' => Spree.install_id,
        'ruby' => RUBY_VERSION,
        'rails' => Rails.version,
        'database' => ActiveRecord::Base.connection_db_config.adapter,
        'dashboard' => 'false',
        'stores' => '1-9',
        'orders' => '0'
      )
      expect(requested_query['gems'].split(',')).to include('spree_core')
      expect(requested_query).not_to have_key('sellers')
    end

    it 'buckets counts so no install is identifiable by its size' do
      allow(Spree::Product).to receive(:count).and_return(4_213)
      allow(Spree::Seller).to receive(:count).and_return(250_000)

      described_class.status

      expect(requested_query).to include('products' => '1k-9k', 'sellers' => '100k+')
    end

    it 'returns newer releases newest first, with links built from the tag' do
      status = described_class.status

      expect(status.releases).to eq(
        [
          { version: '99.1.0', url: 'https://github.com/spree/spree/releases/tag/v99.1.0', published_at: Time.iso8601('2026-10-09T10:00:00Z') },
          { version: '99.0.0', url: 'https://github.com/spree/spree/releases/tag/v99.0.0', published_at: Time.iso8601('2026-10-02T10:51:38Z') }
        ]
      )
      expect(status).to have_attributes(enabled: true, update_available?: true)
      expect(status.checked_at).to be_present
    end

    it 'asks once and answers from the cache for the rest of the day' do
      2.times { described_class.status }

      expect(Net::HTTP).to have_received(:start).once
    end

    it 'offers release candidates only to installs already running one' do
      releases << { 'tag_name' => 'v99.2.0.rc1' }

      allow(Spree).to receive(:version).and_return('6.0.0')
      expect(described_class.status.releases.map { |release| release[:version] }).to eq(%w[99.1.0 99.0.0])

      Rails.cache.clear
      allow(Spree).to receive(:version).and_return('6.0.0.rc1')
      expect(described_class.status.releases.first[:version]).to eq('99.2.0.rc1')
    end

    context 'when the endpoint cannot be reached' do
      before { allow(http).to receive(:get).and_raise(Net::OpenTimeout) }

      it 'reports the error and does not ask again for an hour' do
        expect(Rails.error).to receive(:report).with(an_instance_of(Net::OpenTimeout), hash_including(handled: true)).twice

        2.times { described_class.status }
        expect(described_class.status).to have_attributes(releases: [], update_available?: false)
        expect(Net::HTTP).to have_received(:start).once

        Timecop.travel(61.minutes.from_now) { described_class.status }
        expect(Net::HTTP).to have_received(:start).twice
      end
    end

    context 'when the whole answer takes longer than the overall deadline' do
      before { allow(Timeout).to receive(:timeout).with(described_class::TOTAL_TIMEOUT).and_raise(Timeout::Error) }

      it 'gives up and answers with no update' do
        expect(Rails.error).to receive(:report).with(an_instance_of(Timeout::Error), hash_including(handled: true))

        expect(described_class.status).to have_attributes(enabled: true, update_available?: false)
      end
    end

    context 'when building the usage fields fails' do
      before { allow(Spree::Product).to receive(:count).and_raise(ActiveRecord::StatementInvalid) }

      it 'answers with no update rather than failing the request' do
        expect(Rails.error).to receive(:report).with(an_instance_of(ActiveRecord::StatementInvalid), hash_including(handled: true))

        expect(described_class.status).to have_attributes(enabled: true, update_available?: false)
      end
    end

    context 'when usage reporting is turned off' do
      it 'sends the version only' do
        with_env('SPREE_TELEMETRY_DISABLED' => '1')

        described_class.status

        expect(requested_query).to eq('version' => Spree.version)
      end

      it 'honours DO_NOT_TRACK' do
        with_env('DO_NOT_TRACK' => 'true')

        described_class.status

        expect(requested_query).to eq('version' => Spree.version)
      end

      it 'honours the setting' do
        allow(Spree::Config).to receive(:telemetry_enabled).and_return(false)

        described_class.status

        expect(requested_query).to eq('version' => Spree.version)
      end
    end

    context 'when the update check is turned off' do
      it 'sends nothing and reports itself disabled' do
        with_env('SPREE_UPDATE_CHECK_DISABLED' => '1')

        status = described_class.status

        expect(Net::HTTP).not_to have_received(:start)
        expect(status).to have_attributes(enabled: false, update_available?: false, checked_at: nil)
      end

      it 'honours the setting' do
        allow(Spree::Config).to receive(:update_check_enabled).and_return(false)

        expect(described_class.status.enabled).to be(false)
        expect(Net::HTTP).not_to have_received(:start)
      end
    end

    context 'when running tests' do
      it 'sends nothing so test suites never reach spreecloud.io' do
        allow(Rails.env).to receive(:test?).and_return(true)

        expect(described_class.status.enabled).to be(false)
        expect(Net::HTTP).not_to have_received(:start)
      end

      it 'sends nothing on a CI server, whatever the Rails environment' do
        with_env('CI' => 'true')

        expect(described_class.status.enabled).to be(false)
        expect(Net::HTTP).not_to have_received(:start)
      end
    end
  end
end
