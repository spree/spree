require 'spec_helper'

# Reads the recorded quote so expectations match whatever carriers the
# account can actually offer. Falls back to a placeholder on the very first
# record run, when the cassette does not exist yet.
def recorded_rates
  path = SpreeEasyPost::Engine.root.join('spec/vcr/create_shipment_rates.yml')
  return [{ 'carrier' => 'USPS', 'service' => 'Priority' }] unless path.exist?

  body = YAML.load_file(path)['http_interactions'].last['response']['body']['string']
  JSON.parse(body).fetch('rates')
rescue StandardError
  [{ 'carrier' => 'USPS', 'service' => 'Priority' }]
end

def recorded_rate_or_default = recorded_rates.first


RSpec.describe SpreeEasyPost::FulfillmentProvider do
  let(:store) { @default_store }
  let!(:integration) do
    SpreeEasyPost::Integration.create!(
      store: store,
      preferences: { api_key: ENV.fetch('EASYPOST_TEST_API_KEY', 'EZTK-recorded') }
    ).tap { |record| record.update_columns(active: true) }
  end
  let(:order) { create(:order_with_line_items, store: store) }
  let(:fulfillment) { order.fulfillments.first }

  subject(:provider) { described_class.new }

  before do
    fulfillment.selected_delivery_rate.update_columns(
      metadata: { 'easypost_shipment_id' => 'shp_recorded1', 'easypost_rate_id' => 'rate_recorded1' }
    )
  end

  it 'registers as a shipping fulfillment provider' do
    expect(Spree.fulfillment_providers).to include(described_class)
    expect(described_class.digital?).to be false
    expect(described_class.pickup?).to be false
    expect(described_class.new.requires_address?).to be true
    expect(described_class.provider_name).to eq('EasyPost')
  end

  describe '#create_fulfillment' do
    it 'does not buy twice — an already-purchased label is returned as-is' do
      fulfillment.update_columns(
        tracking: 'EXISTING-123',
        metadata: fulfillment.metadata.merge(
          'easypost_purchased_shipment_id' => 'shp_bought',
          'easypost_tracker_url' => 'https://track.example/t/1'
        )
      )

      expect(client).not_to receive(:shipment)

      result = provider.create_fulfillment(fulfillment)

      expect(result[:tracking_number]).to eq('EXISTING-123')
      expect(result[:tracking_url]).to eq('https://track.example/t/1')
    end

    let(:purchased_shipment) do
      double(
        id: 'shp_recorded1',
        tracking_code: '9405500207552012345678',
        postage_label: double(label_url: 'https://example.com/label.png'),
        tracker: double(public_url: 'https://track.easypost.com/abc')
      )
    end
    let(:shipment_service) { double }
    let(:end_shipper_service) { double }
    let(:client) do
      instance_double(EasyPost::Client, shipment: shipment_service, end_shipper: end_shipper_service)
    end

    before do
      allow_any_instance_of(SpreeEasyPost::Integration).to receive(:client).and_return(client)
      allow(end_shipper_service).to receive(:create).and_return(double(id: 'es_test1'))
    end

    it 'buys the rate quoted at checkout and hands back tracking' do
      allow(shipment_service).to receive(:buy).
        with('shp_recorded1', rate: { id: 'rate_recorded1' }, end_shipper_id: 'es_test1').
        and_return(purchased_shipment)

      result = provider.create_fulfillment(fulfillment)

      expect(result[:tracking_number]).to eq('9405500207552012345678')
      # update_columns silently no-ops on an unknown column, so a rename
      # upstream would leave the label details unwritten rather than raise.
      expect(fulfillment.reload.metadata['easypost_purchased_shipment_id']).to eq('shp_recorded1')
      expect(fulfillment.metadata['easypost_label_url']).to eq('https://example.com/label.png')
      expect(provider.documents(fulfillment)).to eq([{ kind: 'label', url: 'https://example.com/label.png' }])
      expect(provider.tracking_url(fulfillment)).to eq('https://track.easypost.com/abc')
    end

    # EasyPost quotes expire; a stale quote re-quotes from the fulfillment
    # and buys only the exact carrier/service the customer paid for.
    context 'when the quoted rate is stale' do
      let(:fresh_rate) { double(id: 'rate_fresh', carrier: 'UPS', service: 'Ground') }
      let(:fresh_shipment) { double(id: 'shp_fresh', rates: [fresh_rate]) }

      before do
        allow(shipment_service).to receive(:buy).
          with('shp_recorded1', rate: { id: 'rate_recorded1' }, end_shipper_id: 'es_test1').
          and_raise(EasyPost::Errors::EasyPostError.new('rate expired'))
        allow(shipment_service).to receive(:create).and_return(fresh_shipment)
        # The selected rate carries the carrier service the customer chose —
        # the re-quote must buy exactly that.
        fulfillment.selected_delivery_rate.update_columns(carrier: 'UPS', service_level: 'Ground')
      end

      it 'requotes and buys the matching service' do
        allow(shipment_service).to receive(:buy).
          with('shp_fresh', rate: { id: 'rate_fresh' }, end_shipper_id: 'es_test1').
          and_return(purchased_shipment)

        result = provider.create_fulfillment(fulfillment)

        expect(result[:tracking_number]).to eq('9405500207552012345678')
      end

      it 'buys nothing when the exact service is not offered' do
        allow(fresh_rate).to receive(:service).and_return('Express')

        expect(provider.create_fulfillment(fulfillment)).to eq({})
      end
    end

    # Labels on EasyPost's own carrier accounts refuse to buy without an
    # EndShipper, and EasyPost mandates contact fields a stock location
    # does not carry — the store's details fill the gap.
    it 'registers an end shipper from the warehouse with store contact fallbacks' do
      allow(shipment_service).to receive(:buy).and_return(purchased_shipment)

      provider.create_fulfillment(fulfillment)

      expect(end_shipper_service).to have_received(:create).with(
        hash_including(
          name: fulfillment.stock_location.name,
          phone: fulfillment.stock_location.phone,
          email: store.mail_from_address
        )
      )
    end

    it 'buys without an end shipper when the contact details cannot be assembled' do
      fulfillment.stock_location.update_columns(phone: nil)
      store.update_columns(contact_phone: nil)
      allow(shipment_service).to receive(:buy).
        with('shp_recorded1', rate: { id: 'rate_recorded1' }).and_return(purchased_shipment)

      result = provider.create_fulfillment(fulfillment)

      expect(result[:tracking_number]).to be_present
      expect(end_shipper_service).not_to have_received(:create)
    end

    # An end-shipper hiccup must not lose the label — the buy proceeds bare
    # and only carriers that insist on one reject it, with their message.
    it 'degrades to a bare buy when the end shipper cannot be registered' do
      allow(end_shipper_service).to receive(:create).
        and_raise(EasyPost::Errors::EasyPostError.new('nope'))
      allow(Rails.error).to receive(:report)
      allow(shipment_service).to receive(:buy).
        with('shp_recorded1', rate: { id: 'rate_recorded1' }).and_return(purchased_shipment)

      expect(provider.create_fulfillment(fulfillment)[:tracking_number]).to be_present
      expect(Rails.error).to have_received(:report)
    end

    # Runs inside the ship transition — a purchase failure must degrade to
    # "no label yet", never break the fulfillment.
    it 'reports and returns empty on an API failure' do
      allow(shipment_service).to receive(:buy).and_raise(StandardError.new('boom'))
      allow(shipment_service).to receive(:create).and_raise(StandardError.new('boom'))
      allow(Rails.error).to receive(:report)

      expect(provider.create_fulfillment(fulfillment)).to eq({})
      expect(Rails.error).to have_received(:report)
    end

    it 'does nothing without a connected integration' do
      integration.destroy!

      expect(provider.create_fulfillment(fulfillment)).to eq({})
    end
  end

  describe '#cancel_fulfillment' do
    let(:shipment_service) { double }
    let(:client) { instance_double(EasyPost::Client, shipment: shipment_service) }

    before { allow_any_instance_of(SpreeEasyPost::Integration).to receive(:client).and_return(client) }

    it 'refunds the purchased label' do
      fulfillment.update_columns(metadata: { 'easypost_purchased_shipment_id' => 'shp_recorded1' })
      allow(shipment_service).to receive(:refund).with('shp_recorded1').and_return(double)

      expect(provider.cancel_fulfillment(fulfillment)).to be(true)
      expect(shipment_service).to have_received(:refund)
    end

    it 'is a no-op without a purchase' do
      expect(provider.cancel_fulfillment(fulfillment)).to be(true)
    end

    it 'never blocks cancellation on a refund failure' do
      fulfillment.update_columns(metadata: { 'easypost_purchased_shipment_id' => 'shp_recorded1' })
      allow(shipment_service).to receive(:refund).and_raise(StandardError.new('boom'))
      allow(Rails.error).to receive(:report)

      expect(provider.cancel_fulfillment(fulfillment)).to be(false)
      expect(Rails.error).to have_received(:report)
    end
  end

  # Real client, HTTP played back from spec/vcr — the exact buy and refund
  # calls against EasyPost's wire format. Ids come from the recorded rate
  # quote so a re-record against any account stays self-consistent.
  describe 'API contract (VCR)' do
    # USPS purchases demand an EndShipper; the provider registers one from
    # the warehouse before buying, so any recorded USPS service works.
    let(:recorded_rate) do
      rates = recorded_rates
      rates.find { |rate| rate['service'] == 'Priority' } || rates.first
    end

    before do
      fulfillment.selected_delivery_rate.update_columns(
        metadata: {
          'easypost_shipment_id' => recorded_rate['shipment_id'],
          'easypost_rate_id' => recorded_rate['id']
        }
      )
    end

    it 'buys the quoted rate end to end' do
      VCR.use_cassette('buy_shipment') do
        result = provider.create_fulfillment(fulfillment)

        expect(result[:tracking_number]).to be_present
        expect(fulfillment.metadata['easypost_purchased_shipment_id']).to be_present
        expect(fulfillment.metadata['easypost_label_url']).to include('http')
      end
    end

    it 'refunds end to end' do
      fulfillment.update_columns(
        metadata: { 'easypost_purchased_shipment_id' => recorded_rate['shipment_id'] }
      )

      VCR.use_cassette('refund_shipment') do
        expect(provider.cancel_fulfillment(fulfillment)).to be(true)
      end
    end
  end
end
