require 'spec_helper'

class DummyShippingCalculator < Spree::ShippingCalculator
end

describe Spree::DeliveryMethod, type: :model do

  describe 'carrier services' do
    let(:delivery_method) { create(:delivery_method) }

    describe '#services=' do
      it 'creates, updates by id, and destroys omitted rows from a flat payload' do
        delivery_method.services = [
          { carrier: 'UPS', service: 'Ground' },
          { carrier: 'UPS', service: 'NextDayAir', label: 'UPS 1 day' }
        ]
        ground = delivery_method.services.find_by(service: 'Ground')

        delivery_method.services = [
          { id: ground.prefixed_id, carrier: 'UPS', service: 'Ground', markup_flat: 2.5 }
        ]

        expect(delivery_method.services.reload.map(&:service)).to eq(['Ground'])
        expect(ground.reload.markup_flat).to eq(2.5)
      end

      it 'defers rows on a new record until the method is saved' do
        method = build(:delivery_method)
        method.services = [{ carrier: 'USPS', service: 'Priority' }]

        expect(method.pending_services?).to be true
        method.save!

        expect(method.services.reload.map(&:service_key)).to eq(['USPS/Priority'])
      end
    end

    describe '#offers_service?' do
      let(:estimate) { Spree::DeliveryRateProvider::Estimate.new(carrier: 'UPS', service_level: 'Ground') }

      it 'offers everything when no rows exist' do
        expect(delivery_method.offers_service?(estimate)).to be true
      end

      it 'offers only listed services when rows exist' do
        delivery_method.services.create!(carrier: 'USPS', service: 'Priority')

        expect(delivery_method.offers_service?(estimate)).to be false
      end
    end
  end
  let(:delivery_method) { create(:delivery_method) }
  let(:visible_delivery_method) { create :delivery_method, storefront_visible: true }
  let(:admin_only_delivery_method) { create :delivery_method, storefront_visible: false }

  it_behaves_like 'metadata'

  describe 'scopes' do
    let!(:visible_delivery_methods) { create_list(:delivery_method, 2, storefront_visible: true) }
    let!(:admin_only_delivery_methods) { create_list(:delivery_method, 2, storefront_visible: false) }

    describe '.storefront_visible' do
      subject { described_class.storefront_visible }

      it { is_expected.to match_array(visible_delivery_methods) }
    end

    describe '.admin_only' do
      subject { described_class.admin_only }

      it { is_expected.to match_array(admin_only_delivery_methods) }
    end
  end

  describe '#requires_address? / #requires_zone_check?' do
    it 'is true for shipping methods' do
      expect(delivery_method.requires_address?).to be true
      expect(delivery_method.requires_zone_check?).to be true
    end

    it 'is decided by the fulfillment provider' do
      [create(:digital_delivery_method), create(:pickup_delivery_method)].each do |method|
        expect(method.requires_address?).to be false
        expect(method.requires_zone_check?).to be false
      end
    end

    it 'is true for the Manual provider' do
      method = create(:delivery_method)

      expect(method.fulfillment_provider).to eq('Spree::FulfillmentProvider::Manual')
      expect(method.requires_address?).to be true
    end
  end

  describe '#serves_location?' do
    let(:warehouse) { create(:stock_location) }
    let(:counter) { create(:stock_location, pickup_enabled: true) }

    it 'is true for shipping methods regardless of location' do
      expect(delivery_method.serves_location?(warehouse)).to be true
    end

    context 'for a pickup method' do
      let(:pickup_method) { create(:pickup_delivery_method) }

      it 'accepts a package sourced from a pickup-enabled location' do
        expect(pickup_method.serves_location?(counter)).to be true
      end

      it 'rejects a package sourced from a plain warehouse' do
        expect(pickup_method.serves_location?(warehouse)).to be false
      end

      it 'rejects a nil location' do
        expect(pickup_method.serves_location?(nil)).to be false
      end

      it 'respects the configured pickup-location set' do
        other_counter = create(:stock_location, pickup_enabled: true)
        pickup_method.pickup_locations << other_counter

        expect(pickup_method.serves_location?(counter)).to be false
        expect(pickup_method.serves_location?(other_counter)).to be true
      end

      it 'accepts any source when an eligible counter takes remote stock (ship-to-store)' do
        counter.update!(pickup_stock_policy: 'any')

        expect(pickup_method.serves_location?(warehouse)).to be true
      end

      it 'ignores inactive counters' do
        counter.update!(active: false)

        expect(pickup_method.serves_location?(counter)).to be false
      end
    end
  end

  context 'calculators' do
    it "rejects calculators that don't inherit from Spree::ShippingCalculator" do
      allow(described_class).to receive_message_chain(:spree_calculators, :shipping_methods).and_return([
                                                                                                                Spree::Calculator::Shipping::FlatPercentItemTotal,
                                                                                                                Spree::Calculator::Shipping::PriceSack,
                                                                                                                Spree::Calculator::FlatRate,
                                                                                                                DummyShippingCalculator # included as regression test for https://github.com/spree/spree/issues/3109
                                                                                                              ])

      expect(described_class.calculators).to eq([Spree::Calculator::Shipping::FlatPercentItemTotal, Spree::Calculator::Shipping::PriceSack, DummyShippingCalculator])
      expect(described_class.calculators).not_to eq([Spree::Calculator::FlatRate])
    end
  end

  # Regression test for #4492
  context '#shipments' do
    let!(:delivery_method) { create(:delivery_method) }
    let!(:shipment) do
      shipment = create(:shipment)
      shipment.shipping_rates.create!(delivery_method: delivery_method)
      shipment
    end

    it 'can gather all the related shipments' do
      expect(delivery_method.shipments).to include(shipment)
    end
  end

  context 'validations' do
    it 'validates presence of name' do
      subject.valid?
      expect(subject.errors.messages[:name].size).to eq(1)
    end

    it 'defaults to storefront visible and rejects a blank value' do
      expect(subject.storefront_visible).to be true

      subject.storefront_visible = nil
      subject.valid?
      expect(subject.errors.messages[:storefront_visible].size).not_to be_zero
    end

    context 'shipping method does not have a tracking URL mask on file' do
      let(:usps_tracking_number) { '1Z879E930346834440' }

      before { allow(subject).to receive(:tracking_url) { nil } }

      it 'uses tracking number gem to build tracking url' do
        expect(subject.build_tracking_url(usps_tracking_number)).to eq('https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=1Z879E930346834440')
      end
    end
  end

  describe '#rate_provider_instance' do
    let(:delivery_method) { create(:delivery_method) }

    it 'defaults to the Internal provider when unset' do
      expect(delivery_method.rate_provider).to be_blank
      expect(delivery_method.rate_provider_instance).to be_a(Spree::DeliveryRateProvider::Internal)
    end

    it 'constantizes the configured provider and passes itself to it' do
      provider_class = Class.new(Spree::DeliveryRateProvider::Base)
      stub_const('ConfiguredRateProvider', provider_class)
      Spree.delivery_rate_providers << provider_class

      delivery_method.update!(rate_provider: 'ConfiguredRateProvider')

      expect(delivery_method.rate_provider_instance).to be_a(provider_class)
      expect(delivery_method.rate_provider_instance.delivery_method).to eq(delivery_method)
    ensure
      Spree.delivery_rate_providers.delete(provider_class)
    end

    # An unregistered provider would otherwise raise at quote time, deep
    # inside checkout.
    it 'rejects a provider that is not registered' do
      delivery_method.rate_provider = 'NotARegisteredProvider'

      expect(delivery_method).not_to be_valid
      expect(delivery_method.errors[:rate_provider]).to be_present
    end

    it 'keeps rows loadable when a registered provider is later removed' do
      delivery_method.update_columns(rate_provider: 'GoneAwayProvider')

      expect(delivery_method.reload).to be_valid
    end

    # Uninstalling a provider gem leaves its name on existing rows; quoting
    # must fall back rather than raise inside checkout.
    it 'falls back to the default when the stored provider no longer resolves' do
      delivery_method.update_columns(rate_provider: 'GoneAwayProvider')

      expect(delivery_method.reload.rate_provider_instance).to be_a(Spree::DeliveryRateProvider::Internal)
    end

    # The admin picker filters on availability, but a direct API write must
    # not save a provider whose integration isn't connected.
    it 'rejects a registered provider that is unavailable for the store' do
      provider_class = Class.new(Spree::DeliveryRateProvider::Base) do
        def self.integration_class = 'Spree::Integrations::Unconnected'
      end
      stub_const('UnconnectedRateProvider', provider_class)
      Spree.delivery_rate_providers << provider_class

      delivery_method.rate_provider = 'UnconnectedRateProvider'

      expect(delivery_method).not_to be_valid
      expect(delivery_method.errors[:rate_provider]).to be_present
    ensure
      Spree.delivery_rate_providers.delete(provider_class)
    end
  end

  describe 'rate provider / fulfillment provider compatibility' do
    let(:delivery_method) { create(:delivery_method) }
    let(:carrier_provider) do
      Class.new(Spree::DeliveryRateProvider::Base) do
        def self.requires_address? = true
        def self.provider_name = 'Carrier'
      end
    end

    before do
      stub_const('CarrierRateProvider', carrier_provider)
      Spree.delivery_rate_providers << carrier_provider
    end

    after { Spree.delivery_rate_providers.delete(carrier_provider) }

    # A carrier quotes parcels to an address, so it cannot price a method
    # whose fulfillment provider never ships one — the mismatch would surface
    # as missing rates at checkout, not at save time.
    it 'rejects a shipment-quoting rate provider when the method does not ship to an address' do
      profile = create(:digital_delivery_profile, store: delivery_method.store)
      method = build(:digital_delivery_method, store: delivery_method.store,
                     delivery_profile: profile, rate_provider: 'CarrierRateProvider')

      expect(method).not_to be_valid
      expect(method.errors[:rate_provider].join).to include('Carrier')
    end

    it 'accepts a shipment-quoting rate provider on a shipping method' do
      delivery_method.rate_provider = 'CarrierRateProvider'

      expect(delivery_method).to be_valid
    end

    # Internal prices anything — pickup and digital methods keep their
    # calculators.
    it 'accepts any fulfillment provider for rate providers that do not quote shipments' do
      expect(build(:pickup_delivery_method, rate_provider: '')).to be_valid
    end
  end

  # Regression test for #4320
  context 'soft deletion' do
    let(:delivery_method) { create(:delivery_method) }

    it 'soft-deletes when destroy is called' do
      delivery_method.destroy
      expect(delivery_method.deleted_at).not_to be_blank
    end
  end

  describe '#available_to?' do
    context 'for the storefront' do
      it { expect(visible_delivery_method.available_to?(described_class::STOREFRONT)).to be true }
      it { expect(admin_only_delivery_method.available_to?(described_class::STOREFRONT)).to be false }
    end

    context 'for the backoffice' do
      it 'sees every method, visible or not' do
        expect(visible_delivery_method.available_to?(described_class::BACKOFFICE)).to be true
        expect(admin_only_delivery_method.available_to?(described_class::BACKOFFICE)).to be true
      end
    end

    it 'raises on an unknown audience rather than silently narrowing the offer' do
      expect { delivery_method.available_to?(:back_office) }.to raise_error(ArgumentError, /unknown delivery audience/)
    end
  end

  describe 'legacy display_on bridge' do
    before { allow(Spree::Deprecation).to receive(:warn) }

    it 'bridges the old tri-state API onto the boolean' do
      expect(visible_delivery_method.display_on).to eq('both')
      expect(admin_only_delivery_method.display_on).to eq('back_end')

      method = build(:delivery_method, storefront_visible: false)
      expect(method.storefront_visible).to be false

      # front_end-only had no real workflow and folds into visible.
      method.display_on = 'front_end'
      expect(method.storefront_visible).to be true
    end

    it 'accepts the legacy integer filters in #available_to_display?' do
      expect(admin_only_delivery_method.available_to_display?(described_class::DISPLAY_ON_FRONT_END)).to be false
      expect(admin_only_delivery_method.available_to_display?(described_class::DISPLAY_ON_BACK_END)).to be true
    end

    # A legacy caller holding the old constants must not crash mid-checkout.
    it 'accepts the legacy integer filters in #available_to? as well' do
      expect(admin_only_delivery_method.available_to?(described_class::DISPLAY_ON_FRONT_END)).to be false
      expect(admin_only_delivery_method.available_to?(described_class::DISPLAY_ON_BACK_END)).to be true
      expect(visible_delivery_method.available_to?(described_class::DISPLAY_ON_FRONT_END)).to be true
    end
  end

  describe '#delivery_range' do
    context 'without set estimated_transit_business_days_min and estimated_transit_business_days_max' do
      it { expect(delivery_method.delivery_range).to be_nil }
    end

    context 'with set estimated_transit_business_days_min and estimated_transit_business_days_max' do
      let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 2) }

      it { expect(delivery_method.delivery_range).to eq('1-2') }
    end

    context 'when both are the same' do
      let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 1) }

      it { expect(delivery_method.delivery_range).to eq('1') }
    end

    context "when only one transit day value is set" do
      context "when only minimum day is set" do
        let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_min: 1) }

        it { expect(delivery_method.delivery_range).to eq('1') }
      end

      context "when only maximum day is set" do
        let(:delivery_method) { build(:delivery_method, estimated_transit_business_days_max: 2) }

        it { expect(delivery_method.delivery_range).to eq('2') }
      end
    end
  end

  describe '#display_estimated_price' do
    it { expect(delivery_method.display_estimated_price).to eq('Flat rate: $10.00') }

    context 'with the free rate' do
      let(:delivery_method) { build(:free_delivery_method) }

      it { expect(delivery_method.display_estimated_price).to eq('Flat rate: Free') }
    end
  end
  describe '#available_pickup_locations' do
    let(:delivery_method) { create(:delivery_method, store: @default_store) }

    it "falls back to the method's own store's pickup counters, never another store's" do
      own_location = create(:stock_location, store: @default_store, active: true, pickup_enabled: true)
      create(:stock_location, store: create(:store), active: true, pickup_enabled: true)

      expect(delivery_method.available_pickup_locations).to contain_exactly(own_location)
    end
  end

  describe 'seller ownership' do
    let(:seller) { create(:seller, store: @default_store) }

    it 'belongs to the marketplace when no seller is named' do
      expect(create(:delivery_method, store: @default_store)).not_to be_seller_owned
    end

    it "refuses a seller from another store" do
      other_seller = create(:seller, store: create(:store))
      delivery_method = build(:delivery_method, store: @default_store, seller: other_seller)

      expect(delivery_method).not_to be_valid
      expect(delivery_method.errors[:seller]).to be_present
    end

    it 'refuses a carrier rate provider on a seller’s method' do
      carrier_provider = Class.new(Spree::DeliveryRateProvider::Base) do
        def self.provider_name = 'Carrier'
      end
      stub_const('SellerCarrierRateProvider', carrier_provider)
      Spree.delivery_rate_providers << carrier_provider

      delivery_method = build(:delivery_method, store: @default_store, seller: seller,
                                                rate_provider: 'SellerCarrierRateProvider')

      expect(delivery_method).not_to be_valid
      expect(delivery_method.errors[:rate_provider]).to be_present
    ensure
      Spree.delivery_rate_providers.delete(carrier_provider)
    end

    it 'refuses a fulfillment provider other than manual on a seller’s method' do
      delivery_method = build(:delivery_method, store: @default_store, seller: seller,
                                                fulfillment_provider: 'Spree::FulfillmentProvider::Digital')

      expect(delivery_method).not_to be_valid
      expect(delivery_method.errors[:fulfillment_provider]).to be_present
    end

    it 'refuses to share a seller’s own method with the rest of the marketplace' do
      delivery_method = build(:delivery_method, store: @default_store, seller: seller, available_to_sellers: true)

      expect(delivery_method).not_to be_valid
      expect(delivery_method.errors[:available_to_sellers]).to be_present
    end

    # A nil seller_id IS the marketplace's own method, so releasing a departed
    # seller's rows would hand the operator their pricing and start quoting it
    # on first-party packages.
    it "keeps a departed seller's methods pointed at them" do
      delivery_method = create(:delivery_method, store: @default_store, seller: seller)

      seller.destroy

      expect(delivery_method.reload.seller_id).to eq(seller.id)
    end

    describe '.available_to_seller' do
      let!(:marketplace_method) { create(:delivery_method, store: @default_store) }
      let!(:shared_method) { create(:delivery_method, store: @default_store, available_to_sellers: true) }
      let!(:own_method) { create(:delivery_method, store: @default_store, seller: seller) }
      let!(:other_sellers_method) { create(:delivery_method, store: @default_store, seller: create(:seller, store: @default_store)) }

      it "offers a seller their own methods and whatever the operator shares" do
        expect(described_class.available_to_seller(seller)).to contain_exactly(own_method, shared_method)
      end

      it 'offers a first-party package the marketplace methods only' do
        expect(described_class.available_to_seller(nil)).to contain_exactly(marketplace_method, shared_method)
      end

      it "never offers one seller another seller's method" do
        expect(described_class.available_to_seller(seller)).not_to include(other_sellers_method)
      end
    end
  end
end
