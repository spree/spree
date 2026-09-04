require 'spec_helper'

RSpec.describe Spree::Delivery, type: :model do
  let(:store) { @default_store }
  let(:order) { create(:order_ready_to_ship, store: store) }
  let(:fulfillment) { order.fulfillments.first }

  describe 'validations' do
    it 'requires a tracking number' do
      delivery = build(:delivery, owner: fulfillment, tracking_number: nil)

      expect(delivery).not_to be_valid
      expect(delivery.errors[:tracking_number]).to be_present
    end

    it 'refuses the same number twice on one owner' do
      create(:delivery, owner: fulfillment, tracking_number: 'DUP-1')
      duplicate = build(:delivery, owner: fulfillment, tracking_number: 'DUP-1')

      expect(duplicate).not_to be_valid
    end

    it 'allows the same number on another owner' do
      create(:delivery, owner: fulfillment, tracking_number: 'SHARED-1')
      other = build(:delivery, owner: create(:fulfillment, order: create(:order, store: store), tracking: nil), tracking_number: 'SHARED-1')

      expect(other).to be_valid
    end

    it 'rejects a status outside the carrier vocabulary' do
      delivery = build(:delivery, owner: fulfillment, status: 'teleported')

      expect(delivery).not_to be_valid
    end

    # A forwarder's PRO number belongs to a carrier the registry has never
    # heard of, and must still be enterable.
    it 'accepts a carrier the registry does not know' do
      delivery = build(:delivery, owner: fulfillment, carrier: 'Maersk Line')

      expect(delivery).to be_valid
      expect(delivery.carrier_name).to eq('Maersk Line')
    end
  end

  describe 'carrier detection' do
    it 'pins the detected carrier when a recognisable number is saved' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: '1Z879E930346834440')

      expect(delivery.carrier).to eq('ups')
      expect(delivery.carrier_name).to eq('UPS')
    end

    it 'leaves an explicit pick alone' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: '1Z879E930346834440', carrier: 'inpost')

      expect(delivery.carrier).to eq('inpost')
      expect(delivery.carrier_name).to eq('InPost')
    end

    it 'pins nothing for an unrecognisable number' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: '421432')

      expect(delivery.carrier).to be_nil
    end
  end

  describe '#resolved_tracking_url' do
    it 'returns a pasted link as-is' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: 'https://carrier.example/track/ABC')

      expect(delivery.resolved_tracking_url).to eq('https://carrier.example/track/ABC')
    end

    it 'prefers the stored link' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: '1Z879E930346834440', tracking_url: 'https://tracker.example/t/1')

      expect(delivery.resolved_tracking_url).to eq('https://tracker.example/t/1')
    end

    # The column says what the merchant chose; the reader says what to show.
    # Keeping them apart is what lets a cleared field stay cleared.
    it 'leaves the stored column alone' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: '1Z879E930346834440')

      expect(delivery.tracking_url).to be_nil
      expect(delivery.resolved_tracking_url).to include('ups.com')
    end

    # The provider bought the label, so its tracker page wins over anything
    # derived — it is the one link guaranteed to show this parcel.
    it 'asks the owner provider next' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: 'RANDOM123')
      allow(fulfillment).to receive(:provider).and_return(
        instance_double(Spree::FulfillmentProvider::Manual, tracking_url: 'https://provider.example/t/1')
      )
      delivery.owner = fulfillment

      expect(delivery.resolved_tracking_url).to eq('https://provider.example/t/1')
    end

    it 'builds from the pinned carrier registry entry' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: '421432', carrier: 'inpost')

      expect(delivery.resolved_tracking_url).to eq('https://inpost.pl/sledzenie-przesylek?number=421432')
    end

    it 'uses the delivery method format when there is no carrier' do
      allow(fulfillment.delivery_method).to receive(:build_tracking_url).with('ABC-1').and_return('https://method.example/ABC-1')
      delivery = create(:delivery, owner: fulfillment, tracking_number: 'ABC-1')
      delivery.owner = fulfillment

      expect(delivery.resolved_tracking_url).to eq('https://method.example/ABC-1')
    end

    # No method, no carrier, no provider — a recognisable number still yields
    # its carrier's page through the tracking_number gem.
    it 'falls back to detection from the number format' do
      delivery = create(:delivery, owner: fulfillment, tracking_number: '1Z879E930346834440', carrier: 'unknown_courier')
      allow(fulfillment).to receive(:delivery_method).and_return(nil)
      delivery.owner = fulfillment

      expect(delivery.resolved_tracking_url).to include('ups.com')
    end
  end

  describe 'scopes' do
    it 'orders chronologically and tells delivered from open' do
      fulfillment.deliveries.destroy_all
      first = create(:delivery, owner: fulfillment, tracking_number: 'A1', created_at: 2.days.ago)
      second = create(:delivery, :delivered, owner: fulfillment, tracking_number: 'A2')

      expect(fulfillment.deliveries.chronological).to eq([first, second])
      expect(fulfillment.deliveries.delivered).to eq([second])
      expect(fulfillment.deliveries.undelivered).to eq([first])
    end
  end
  describe '#correction_attributes' do
    let(:delivery) do
      create(:delivery, owner: fulfillment, store: store, tracking_number: '1Z_OLD',
                        carrier: 'ups', tracking_url: 'https://ups.example/1Z_OLD',
                        status: 'delivered', delivered_at: 2.days.ago)
    end

    # To a carrier a different number is a different parcel, so nothing about
    # the old one may survive onto it — least of all an arrival, which is what
    # the returns window counts from.
    it 'starts the journey over and drops the old parcel arrival' do
      corrected = delivery.correction_attributes(tracking_number: '9400_NEW')

      expect(corrected[:status]).to eq('pending')
      expect(corrected[:delivered_at]).to be_nil
      expect(corrected[:carrier]).to be_nil
      expect(corrected[:tracking_url]).to be_nil
    end

    it 'leaves an edit that is not a correction alone' do
      expect(delivery.correction_attributes(carrier: 'fedex')).to eq(carrier: 'fedex')
    end

    it 'keeps a carrier the merchant supplied with the new number' do
      corrected = delivery.correction_attributes(tracking_number: '9400_NEW', carrier: 'fedex')

      expect(corrected[:carrier]).to eq('fedex')
    end

    it 'treats the same number with stray whitespace as no correction' do
      expect(delivery.correction_attributes(tracking_number: ' 1Z_OLD ')).not_to have_key(:status)
    end
  end
end
