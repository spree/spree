require 'spec_helper'

RSpec.describe SpreeEasyPost::DeliveryRateProvider do
  let(:store) { @default_store }
  # let! — the delivery method's rate_provider validation requires a
  # connected integration to exist at create time.
  let!(:integration) do
    SpreeEasyPost::Integration.new(store: store, active: true, preferences: { api_key: 'EZTK-test' }).tap do |record|
      allow(record).to receive(:can_connect?).and_return(true)
      record.save!
    end
  end
  let(:delivery_method) do
    create(:delivery_method, store: store,
                             rate_provider: described_class.to_s,
                             metadata: { 'carrier' => 'UPS', 'service' => 'Ground' })
  end
  let(:order) { create(:order_with_line_items, store: store) }
  let(:package) { order.fulfillments.first.to_package }

  subject(:provider) { described_class.new(delivery_method) }

  let(:ground_rate) do
    double(carrier: 'UPS', service: 'Ground', rate: '8.99',
           delivery_date: '2026-08-12', id: 'rate_1', shipment_id: 'shp_1')
  end
  let(:express_rate) do
    double(carrier: 'UPS', service: 'Express', rate: '24.99',
           delivery_date: '2026-08-08', id: 'rate_2', shipment_id: 'shp_1')
  end
  let(:easypost_shipment) { double(rates: [ground_rate, express_rate]) }
  let(:shipment_service) { double(create: easypost_shipment) }
  let(:client) { instance_double(EasyPost::Client, shipment: shipment_service) }

  before do
    allow(integration).to receive(:client).and_return(client)
    allow(provider).to receive(:integration).and_return(integration)
    Spree::Current.reset
  end

  it 'registers itself and declares its integration' do
    expect(Spree.delivery_rate_providers).to include(described_class)
    expect(described_class.integration_class).to eq('SpreeEasyPost::Integration')
  end

  describe '#estimate' do
    it 'quotes the configured carrier service with enriched fields' do
      estimate = provider.estimate(package)

      expect(estimate.cost).to eq(BigDecimal('8.99'))
      expect(estimate.carrier).to eq('UPS')
      expect(estimate.service_level).to eq('Ground')
      expect(estimate.estimated_delivery_date).to eq(Date.new(2026, 8, 12))
      expect(estimate.metadata['easypost_rate_id']).to eq('rate_1')
    end

    it 'suppresses the method when no rate matches the configured service' do
      delivery_method.metadata['service'] = 'Overnight'

      expect(provider.estimate(package)).to be_nil
    end

    it 'suppresses the method when the integration is not connected' do
      allow(provider).to receive(:integration).and_return(nil)

      expect(provider.estimate(package)).to be_nil
    end

    # The whole point of the shared shipment call: several methods quoting
    # through this provider must cost one API round-trip, not one each.
    it 'reuses the shipment across methods within a request' do
      express_method = create(:delivery_method, store: store,
                                                rate_provider: described_class.to_s,
                                                metadata: { 'carrier' => 'UPS', 'service' => 'Express' })
      express_provider = described_class.new(express_method)
      allow(express_provider).to receive(:integration).and_return(integration)

      provider.estimate(package)
      express_estimate = express_provider.estimate(package)

      expect(shipment_service).to have_received(:create).once
      expect(express_estimate.cost).to eq(BigDecimal('24.99'))
    end
  end
end
