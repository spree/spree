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
    create(:delivery_method, store: store, rate_provider: described_class.to_s)
  end
  let(:order) { create(:order_with_line_items, store: store) }
  let(:package) { order.fulfillments.first.to_package }

  subject(:provider) { described_class.new(delivery_method) }

  let(:ground_rate) do
    double(carrier: 'UPS', service: 'Ground', rate: '8.99', currency: 'USD',
           delivery_date: '2026-08-12', id: 'rate_1', shipment_id: 'shp_1')
  end
  let(:express_rate) do
    double(carrier: 'UPS', service: 'Express', rate: '24.99', currency: 'USD',
           delivery_date: '2026-08-08', id: 'rate_2', shipment_id: 'shp_1')
  end
  let(:easypost_shipment) { double(rates: [ground_rate, express_rate]) }
  let(:shipment_service) { double(create: easypost_shipment) }
  let(:client) { instance_double(EasyPost::Client, shipment: shipment_service) }

  before do
    allow(integration).to receive(:client).and_return(client)
    allow(provider).to receive(:integration).and_return(integration)
  end

  it 'registers itself and declares its integration' do
    expect(Spree.delivery_rate_providers).to include(described_class)
    expect(described_class.integration_class).to eq('SpreeEasyPost::Integration')
  end

  describe '.service_catalog' do
    it 'lists every carrier service the account can quote' do
      catalog = described_class.service_catalog(integration)

      expect(catalog).to be_available
      expect(catalog.services).to eq(
        [
          { carrier: 'UPS', service: 'Express', label: 'UPS Express' },
          { carrier: 'UPS', service: 'Ground', label: 'UPS Ground' }
        ]
      )
    end

    # A carrier outage or a rejected key must say why, so the picker does
    # not imply the merchant simply has no carriers.
    it 'reports the carrier message when the probe quote fails' do
      allow(shipment_service).to receive(:create).
        and_raise(StandardError.new('This resource requires a production API Key to access.'))

      catalog = described_class.service_catalog(integration)

      expect(catalog).not_to be_available
      expect(catalog.error_message).to include('production API Key')
      expect(catalog.services).to eq([])
    end

    it 'lists nothing when the integration is not connected' do
      expect(described_class.service_catalog(nil).services).to eq([])
    end
  end

  describe '#estimates' do
    it 'maps every returned rate to an enriched estimate' do
      estimates = provider.estimates(package)

      expect(estimates.size).to eq(2)
      ground = estimates.detect { |estimate| estimate.service_level == 'Ground' }
      expect(ground.cost).to eq(BigDecimal('8.99'))
      expect(ground.carrier).to eq('UPS')
      expect(ground.estimated_delivery_date).to eq(Date.new(2026, 8, 12))
      expect(ground.metadata['easypost_rate_id']).to eq('rate_1')
      expect(ground.metadata['easypost_shipment_id']).to eq('shp_1')
    end

    # During checkout the package belongs to a Cart, not an Order — the
    # regression this guards had the provider walking to a stranger's order
    # (whose nil address then killed rating inside the provider's rescue).
    it 'quotes for a cart-owned package against the cart ship address' do
      cart = create(:cart, store: store, ship_address: create(:address))
      create(:line_item, cart: cart, order: nil)
      fulfillment = create(:shipment, cart: cart, order: nil, stock_location: create(:stock_location))

      sent_to_address = nil
      allow(shipment_service).to receive(:create) do |params|
        sent_to_address = params[:to_address]
        easypost_shipment
      end

      estimates = provider.estimates(fulfillment.to_package)

      expect(estimates.size).to eq(2)
      # The destination must be the CART's address — the regression had it
      # reading a stranger order's (nil) address instead.
      expect(sent_to_address[:zip]).to eq(cart.ship_address.postal_code)
    end

    it 'declines to quote when the owner has no ship address yet' do
      cart = create(:cart, store: store, ship_address: nil)
      create(:line_item, cart: cart, order: nil)
      fulfillment = create(:shipment, cart: cart, order: nil, stock_location: create(:stock_location))

      expect(provider.estimates(fulfillment.to_package)).to eq([])
    end

    # A carrier outage must degrade to "method not offered", never break
    # the rate refresh.
    it 'returns nothing and reports when the API call fails' do
      allow(shipment_service).to receive(:create).and_raise(StandardError.new('timeout'))
      allow(Rails.error).to receive(:report)

      expect(provider.estimates(package)).to eq([])
      expect(Rails.error).to have_received(:report)
    end

    it 'returns nothing when the integration is not connected' do
      allow(provider).to receive(:integration).and_return(nil)

      expect(provider.estimates(package)).to eq([])
    end

    # EasyPost accepts the shipment (201) but attaches rate_error messages
    # instead of rates when it cannot quote — without logging them, "no
    # delivery options" is undiagnosable (e.g. an origin with no zip code).
    it 'logs the carrier rate errors when the shipment comes back with no rates' do
      rate_error = double(
        carrier: 'USPS',
        carrier_account_id: 'ca_1',
        message: 'Unable to retrieve USPS rates without a valid origin zip code.'
      )
      empty_shipment = double(id: 'shp_empty', rates: [], messages: [rate_error, rate_error])
      allow(shipment_service).to receive(:create).and_return(empty_shipment)
      allow(Rails.logger).to receive(:warn)

      expect(provider.estimates(package)).to eq([])
      expect(Rails.logger).to have_received(:warn).with(
        a_string_including('no rates', delivery_method.name, 'shp_empty', 'valid origin zip code')
      )
    end

    # Two linked accounts for one carrier can fail for different reasons;
    # collapsing them on carrier alone would hide one.
    it 'keeps per-account rate errors distinct' do
      first_account = double(carrier: 'UPS', carrier_account_id: 'ca_1', message: 'Invalid origin zip')
      second_account = double(carrier: 'UPS', carrier_account_id: 'ca_2', message: 'Account not authorized')
      empty_shipment = double(id: 'shp_empty', rates: [], messages: [first_account, second_account])
      allow(shipment_service).to receive(:create).and_return(empty_shipment)
      allow(Rails.logger).to receive(:warn)

      expect(provider.estimates(package)).to eq([])
      expect(Rails.logger).to have_received(:warn).with(
        a_string_including('UPS/ca_1', 'Invalid origin zip', 'UPS/ca_2', 'Account not authorized')
      )
    end

    it 'logs even when EasyPost gives no reason for the empty rate list' do
      empty_shipment = double(id: 'shp_empty', rates: [], messages: [])
      allow(shipment_service).to receive(:create).and_return(empty_shipment)
      allow(Rails.logger).to receive(:warn)

      expect(provider.estimates(package)).to eq([])
      expect(Rails.logger).to have_received(:warn).with(a_string_including('no carrier messages given'))
    end

    describe 'parcel dimensions' do
      before do
        create(:package_type, store: store, default: true, length: 12, width: 9, height: 4,
                              dimensions_unit: 'in')
      end

      it 'sends the default package dimensions with the quote' do
        provider.estimates(package)

        expect(shipment_service).to have_received(:create).with(
          hash_including(parcel: hash_including(length: 12.0, width: 9.0, height: 4.0))
        )
      end

      it 'converts a metric store dimensions to inches' do
        store.update!(preferred_unit_system: 'metric')
        store.default_package_type.update!(length: 30.48, width: 22.86, height: 10.16,
                                           dimensions_unit: 'cm')

        provider.estimates(package)

        expect(shipment_service).to have_received(:create).with(
          hash_including(parcel: hash_including(length: 12.0, width: 9.0, height: 4.0))
        )
      end

      # A merchant can record a carton in whatever unit the supplier quoted
      # it in, regardless of what the store trades in. Reading centimetres as
      # inches overstates every axis by 2.54 and inflates the carrier's
      # dimensional-weight price.
      it 'converts a box recorded in a different unit than the store uses' do
        store.default_package_type.update!(length: 30.48, width: 22.86, height: 10.16,
                                           dimensions_unit: 'cm')

        provider.estimates(package)

        expect(shipment_service).to have_received(:create).with(
          hash_including(parcel: hash_including(length: 12.0, width: 9.0, height: 4.0))
        )
      end
    end

    # The whole point of the shared shipment call: several methods quoting
    # through this provider must cost one API round-trip, not one each.
    it 'reuses the shipment across methods within a request' do
      other_method = create(:delivery_method, store: store, rate_provider: described_class.to_s)
      other_provider = described_class.new(other_method)
      allow(other_provider).to receive(:integration).and_return(integration)

      provider.estimates(package)
      other_estimates = other_provider.estimates(package)

      expect(shipment_service).to have_received(:create).once
      expect(other_estimates.size).to eq(2)
    end
  end
end

# Real client and integration, HTTP played back from spec/vcr — proves the
# provider's shipment.create call shape and rate mapping against EasyPost's
# wire format, not a hand-stubbed double.
RSpec.describe SpreeEasyPost::DeliveryRateProvider, 'API contract (VCR)' do
  let(:store) { @default_store }
  let!(:integration) do
    SpreeEasyPost::Integration.create!(
      store: store,
      preferences: { api_key: ENV.fetch('EASYPOST_TEST_API_KEY', 'EZTK-recorded') }
    ).tap { |record| record.update_columns(active: true) }
  end
  let(:delivery_method) do
    create(:delivery_method, store: store, rate_provider: described_class.to_s)
  end
  let(:order) { create(:order_with_line_items, store: store) }
  let(:package) { order.fulfillments.first.to_package }

  it 'quotes every recorded carrier service end to end' do
    delivery_method # lazy let — must exist before the estimator queries methods

    VCR.use_cassette('create_shipment_rates') do
      rates = Spree::Stock::Estimator.new(order).delivery_rates(package)
                                     .select { |rate| rate.delivery_method_id == delivery_method.id }

      expect(rates.size).to eq(recorded_rates.size)
      expect(rates.map(&:carrier)).to match_array(recorded_rates.map { |rate| rate['carrier'] })
      rates.each do |rate|
        expect(rate.name).to eq("#{rate.carrier} #{rate.service_level}")
        expect(rate.cost).to be > 0
        expect(rate.metadata['easypost_rate_id']).to be_present
      end
    end
  end

  # The merchant controls: rows narrow the offer, labels rename, markup
  # applies — all through the estimator with recorded HTTP.
  it 'narrows, renames and marks up services through service rows' do
    picked = recorded_rate_or_default
    delivery_method.update!(markup_percent: 10)
    delivery_method.services.create!(
      carrier: picked['carrier'], service: picked['service'], label: 'Custom fast shipping'
    )

    VCR.use_cassette('create_shipment_rates') do
      rates = Spree::Stock::Estimator.new(order).delivery_rates(package)
                                     .select { |rate| rate.delivery_method_id == delivery_method.id }

      expect(rates.size).to eq(1)
      rate = rates.first
      expect(rate.name).to eq('Custom fast shipping')
      expect(rate.service_level).to eq(picked['service'])
      expect(rate.cost).to eq((BigDecimal(picked['rate'].to_s) * BigDecimal('1.1')).round(2))
    end
  end
end
