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
    expect(described_class.generates_labels?).to be true
    expect(described_class.new.requires_address?).to be true
    expect(described_class.provider_name).to eq('EasyPost')
  end

  describe '#purchase_label' do
    let(:purchased_shipment) do
      double(
        id: 'shp_recorded1',
        tracking_code: '9405500207552012345678',
        selected_rate: double(id: 'rate_recorded1', carrier: 'USPS', service: 'Priority', rate: '7.25', currency: 'USD'),
        postage_label: double(label_url: 'https://example.com/label.png', label_file_type: 'image/png'),
        tracker: double(id: 'trk_1', public_url: 'https://track.easypost.com/abc'),
        forms: []
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

    it 'buys the rate quoted at checkout and answers with a typed purchase' do
      allow(shipment_service).to receive(:buy).
        with('shp_recorded1', rate: { id: 'rate_recorded1' }, end_shipper_id: 'es_test1').
        and_return(purchased_shipment)

      purchase = provider.purchase_label(fulfillment)

      expect(purchase).to be_a(Spree::LabelPurchase)
      expect(purchase).to be_valid
      expect(purchase.tracking_number).to eq('9405500207552012345678')
      expect(purchase.external_id).to eq('shp_recorded1')
      # Mapped onto the Spree.tracking_carriers key, so a bought label gets
      # the same badge a hand-entered number would.
      expect(purchase.carrier).to eq('usps')
      expect(purchase.service).to eq('Priority')
      expect(purchase.cost).to eq(7.25)
      expect(purchase.currency).to eq('USD')
      expect(purchase.format).to eq('png')
      expect(purchase.file_url).to eq('https://example.com/label.png')
      expect(purchase.tracking_url).to eq('https://track.easypost.com/abc')
      expect(purchase.metadata).to include('easypost_tracker_url' => 'https://track.easypost.com/abc')
    end

    # Core refuses a second purchase while a label is active, so the provider
    # keeps no state of its own.
    it 'writes nothing onto the fulfillment' do
      allow(shipment_service).to receive(:buy).and_return(purchased_shipment)

      expect { provider.purchase_label(fulfillment) }.not_to change { fulfillment.reload.metadata }
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
        fulfillment.selected_delivery_rate.update_columns(carrier: 'UPS', service_level: 'Ground')
      end

      it 'requotes and buys the matching service' do
        allow(shipment_service).to receive(:buy).
          with('shp_fresh', rate: { id: 'rate_fresh' }, end_shipper_id: 'es_test1').
          and_return(purchased_shipment)

        expect(provider.purchase_label(fulfillment).tracking_number).to eq('9405500207552012345678')
      end

      # Silently buying a different service than the customer paid for is
      # worse than no label, so the refusal names the service rather than
      # answering nil with no reason given.
      it 'refuses by name when the exact service is not offered' do
        allow(fresh_rate).to receive(:service).and_return('Express')

        expect { provider.purchase_label(fulfillment) }.
          to raise_error(Spree::Core::LabelPurchaseRefused, /Ground/)
      end
    end

    # Labels on EasyPost's own carrier accounts refuse to buy without an
    # EndShipper, and EasyPost mandates contact fields a stock location
    # does not carry — the store's details fill the gap.
    it 'registers an end shipper from the warehouse with store contact fallbacks' do
      allow(shipment_service).to receive(:buy).and_return(purchased_shipment)

      provider.purchase_label(fulfillment)

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

      expect(provider.purchase_label(fulfillment)).to be_present
      expect(end_shipper_service).not_to have_received(:create)
    end

    # The carrier's own answer to a buy without an end shipper is a bare
    # "malformed syntax", which sends a merchant looking at the integration
    # rather than at the warehouse address that was actually refused.
    it 'names the location when the carrier will not verify its address' do
      allow(Rails.error).to receive(:report)
      fresh_rate = double(id: 'rate_fresh', carrier: 'USPS', service: 'Priority')
      allow(shipment_service).to receive(:create).and_return(double(id: 'shp_fresh', rates: [fresh_rate]))
      fulfillment.selected_delivery_rate.update_columns(carrier: 'USPS', service_level: 'Priority')
      allow(end_shipper_service).to receive(:create).
        and_raise(EasyPost::Errors::EasyPostError.new('Unable to verify address.'))

      expect { provider.purchase_label(fulfillment) }.
        to raise_error(Spree::Core::LabelPurchaseRefused, /#{Regexp.escape(fulfillment.stock_location.name)}/)
    end

    it 'reports and answers nil on an API failure' do
      allow(shipment_service).to receive(:buy).and_raise(StandardError.new('boom'))
      allow(shipment_service).to receive(:create).and_raise(StandardError.new('boom'))
      allow(Rails.error).to receive(:report)

      expect(provider.purchase_label(fulfillment)).to be_nil
      expect(Rails.error).to have_received(:report)
    end

    it 'does nothing without a connected integration' do
      integration.destroy!

      expect(provider.purchase_label(fulfillment)).to be_nil
    end

    describe 'for a return' do
      let(:shipped) { create(:shipped_order, store: store) }
      let(:return_record) { create(:return, order: shipped) }
      let(:return_shipment) do
        double(
          id: 'shp_return1',
          rates: [
            double(id: 'rate_cheap', carrier: 'USPS', service: 'Ground', rate: '4.10', currency: 'USD'),
            double(id: 'rate_dear', carrier: 'UPS', service: 'Express', rate: '19.00', currency: 'USD')
          ]
        )
      end

      before do
        allow(shipment_service).to receive(:create).and_return(return_shipment)
        allow(shipment_service).to receive(:buy).and_return(purchased_shipment)
      end

      # Return postage is the merchant's own money and no service was ever
      # chosen for it, so the cheapest the account offers wins.
      it 'buys an inbound shipment at the cheapest rate' do
        purchase = provider.purchase_label(return_record)

        expect(purchase.tracking_number).to be_present
        expect(shipment_service).to have_received(:create).with(hash_including(is_return: true))
        expect(shipment_service).to have_received(:buy).with('shp_return1', hash_including(rate: { id: 'rate_cheap' }))
      end

      it 'ships from the customer address back to the return stock location' do
        provider.purchase_label(return_record)

        expect(shipment_service).to have_received(:create).with(
          hash_including(
            from_address: hash_including(zip: shipped.ship_address.zipcode),
            to_address: hash_including(zip: return_record.stock_location.zipcode)
          )
        )
      end
    end
  end

  describe '#refund_label' do
    let(:shipment_service) { double }
    let(:client) { instance_double(EasyPost::Client, shipment: shipment_service) }
    let(:shipping_label) { create(:shipping_label, owner: fulfillment, store: store, external_id: 'shp_recorded1') }

    before { allow_any_instance_of(SpreeEasyPost::Integration).to receive(:client).and_return(client) }

    it 'reports a settled refund' do
      allow(shipment_service).to receive(:refund).with('shp_recorded1').and_return(double(refund_status: 'refunded'))

      expect(provider.refund_label(shipping_label)).to eq('refunded')
    end

    # USPS settles refunds later; the label waits in refund_requested until a
    # webhook confirms it.
    it 'reports a submitted refund as pending' do
      allow(shipment_service).to receive(:refund).and_return(double(refund_status: 'submitted'))

      expect(provider.refund_label(shipping_label)).to eq('refund_requested')
    end

    it 'reports a rejection as a failure' do
      allow(shipment_service).to receive(:refund).and_return(double(refund_status: 'rejected'))

      expect(provider.refund_label(shipping_label)).to be(false)
    end

    it 'never raises on an API failure' do
      allow(shipment_service).to receive(:refund).and_raise(StandardError.new('boom'))
      allow(Rails.error).to receive(:report)

      expect(provider.refund_label(shipping_label)).to be(false)
      expect(Rails.error).to have_received(:report)
    end
  end

  describe '#tracking_url' do
    it 'answers the tracker page recorded on the delivery label' do
      label = create(:shipping_label, :with_delivery, owner: fulfillment, store: store,
                                                      metadata: { 'easypost_tracker_url' => 'https://track.easypost.com/abc' })

      expect(provider.tracking_url(label.delivery)).to eq('https://track.easypost.com/abc')
    end
  end

  describe '#documents' do
    # The label is a Spree::ShippingLabel; only the paperwork beside it is
    # reported here.
    it 'lists customs forms and never the label' do
      create(
        :shipping_label, owner: fulfillment, store: store,
                         metadata: { 'easypost_forms' => [{ 'form_type' => 'commercial_invoice', 'url' => 'https://forms.example/ci.pdf' }] }
      )

      expect(provider.documents(fulfillment)).to eq([{ kind: 'commercial_invoice', url: 'https://forms.example/ci.pdf' }])
    end

    it 'is empty without a label' do
      expect(provider.documents(fulfillment)).to eq([])
    end
  end

  # Real client, HTTP played back from spec/vcr — the exact buy and refund
  # calls against EasyPost's wire format. Ids come from the recorded rate
  # quote so a re-record against any account stays self-consistent.
  describe 'API contract (VCR)' do
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
        purchase = provider.purchase_label(fulfillment)

        expect(purchase.tracking_number).to be_present
        expect(purchase.external_id).to be_present
        expect(purchase.file_url).to include('http')
      end
    end

    it 'refunds end to end' do
      shipping_label = create(
        :shipping_label, owner: fulfillment, store: store, external_id: recorded_rate['shipment_id']
      )

      VCR.use_cassette('refund_shipment') do
        expect(provider.refund_label(shipping_label)).to be_present
      end
    end
  end
end
