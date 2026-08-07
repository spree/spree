require 'spec_helper'

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
    expect(described_class.fulfillment_types).to eq(['shipping'])
    expect(described_class.provider_name).to eq('EasyPost')
  end

  describe '#create_fulfillment' do
    let(:purchased_shipment) do
      double(
        id: 'shp_recorded1',
        tracking_code: '9405500207552012345678',
        postage_label: double(label_url: 'https://example.com/label.png'),
        tracker: double(public_url: 'https://track.easypost.com/abc')
      )
    end
    let(:shipment_service) { double }
    let(:client) { instance_double(EasyPost::Client, shipment: shipment_service) }

    before { allow_any_instance_of(SpreeEasyPost::Integration).to receive(:client).and_return(client) }

    it 'buys the rate quoted at checkout and hands back tracking' do
      allow(shipment_service).to receive(:buy).
        with('shp_recorded1', rate: { id: 'rate_recorded1' }).and_return(purchased_shipment)

      result = provider.create_fulfillment(fulfillment)

      expect(result[:tracking_number]).to eq('9405500207552012345678')
      expect(fulfillment.metadata['easypost_purchased_shipment_id']).to eq('shp_recorded1')
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
          with('shp_recorded1', rate: { id: 'rate_recorded1' }).
          and_raise(EasyPost::Errors::EasyPostError.new('rate expired'))
        allow(shipment_service).to receive(:create).and_return(fresh_shipment)
        fulfillment.delivery_method.update_columns(
          private_metadata: { 'carrier' => 'UPS', 'service' => 'Ground' }
        )
      end

      it 'requotes and buys the matching service' do
        allow(shipment_service).to receive(:buy).
          with('shp_fresh', rate: { id: 'rate_fresh' }).and_return(purchased_shipment)

        result = provider.create_fulfillment(fulfillment)

        expect(result[:tracking_number]).to eq('9405500207552012345678')
      end

      it 'buys nothing when the exact service is not offered' do
        allow(fresh_rate).to receive(:service).and_return('Express')

        expect(provider.create_fulfillment(fulfillment)).to eq({})
      end
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
      fulfillment.update_columns(private_metadata: { 'easypost_purchased_shipment_id' => 'shp_recorded1' })
      allow(shipment_service).to receive(:refund).with('shp_recorded1').and_return(double)

      expect(provider.cancel_fulfillment(fulfillment)).to be(true)
      expect(shipment_service).to have_received(:refund)
    end

    it 'is a no-op without a purchase' do
      expect(provider.cancel_fulfillment(fulfillment)).to be(true)
    end

    it 'never blocks cancellation on a refund failure' do
      fulfillment.update_columns(private_metadata: { 'easypost_purchased_shipment_id' => 'shp_recorded1' })
      allow(shipment_service).to receive(:refund).and_raise(StandardError.new('boom'))
      allow(Rails.error).to receive(:report)

      expect(provider.cancel_fulfillment(fulfillment)).to be(false)
      expect(Rails.error).to have_received(:report)
    end
  end

  # Real client, HTTP played back from spec/vcr — the exact buy and refund
  # calls against EasyPost's wire format.
  describe 'API contract (VCR)' do
    it 'buys the quoted rate end to end' do
      VCR.use_cassette('buy_shipment') do
        result = provider.create_fulfillment(fulfillment)

        expect(result[:tracking_number]).to eq('9405500207552012345678')
        expect(fulfillment.metadata['easypost_label_url']).to include('postage_label')
        expect(provider.tracking_url(fulfillment)).to include('track.easypost.com')
      end
    end

    it 'refunds end to end' do
      fulfillment.update_columns(private_metadata: { 'easypost_purchased_shipment_id' => 'shp_recorded1' })

      VCR.use_cassette('refund_shipment') do
        expect(provider.cancel_fulfillment(fulfillment)).to be(true)
      end
    end
  end
end
