require 'spec_helper'

describe Spree::Store, type: :model do
  describe 'associations' do
    subject { create(:store) }

    describe '#products' do
      let!(:product) { create(:product, stores: [subject]) }
      let!(:product_2) { create(:product, stores: [create(:store)]) }

      it { expect(subject.products).to eq([product]) }

      describe '#product_properties' do
        let!(:product_property) { create(:product_property, product: product) }
        let!(:product_property_2) { create(:product_property, product: product_2) }

        it { expect(subject.product_properties).to eq([product_property]) }
      end

      describe '#variants' do
        let!(:variant) { create(:variant, product: product) }
        let!(:variant_2) { create(:variant, product: product_2) }

        it { expect(subject.variants).to eq([product.master, variant]) }

        describe '#stock_items' do
          let!(:stock_items) { product.stock_items }
          let!(:stock_items_2) { product_2.stock_items }

          it { expect(stock_items).not_to be_empty }
          it { expect(stock_items_2).not_to be_empty }
          it { expect(subject.stock_items).to eq(stock_items) }
        end
      end
    end

    describe '#payment_methods' do
      let!(:payment_method) { create(:payment_method, stores: [subject]) }
      let!(:payment_method_2) { create(:payment_method, stores: [create(:store)]) }

      it { expect(subject.payment_methods).to eq([payment_method]) }
    end

    describe '#orders' do
      let!(:order) { create(:order, store: subject) }
      let!(:order_2) { create(:order, store: create(:store)) }

      it { expect(subject.orders).to eq([order]) }

      describe '#line_items' do
        let!(:line_item) { create(:line_item, order: order) }
        let!(:line_item_2) { create(:line_item, order: order_2) }

        it { expect(subject.line_items).to eq([line_item]) }
      end

      describe '#payments' do
        let!(:payment) { create(:payment, order: order) }
        let!(:payment_2) { create(:payment, order: order_2) }

        it { expect(subject.payments).to eq([payment]) }
      end

      describe '#shipments' do
        let!(:shipment) { create(:shipment, order: order) }
        let!(:shipment_2) { create(:shipment, order: order_2) }

        it { expect(subject.shipments).to eq([shipment]) }
      end

      describe '#return_authorizations' do
        let!(:order) { create(:shipped_order, store: subject) }
        let!(:order_2) { create(:shipped_order, store: create(:store)) }
        let!(:return_authorization) { create(:return_authorization, order: order) }
        let!(:return_authorization_2) { create(:return_authorization, order: order_2) }

        it { expect(subject.return_authorizations).to eq([return_authorization]) }
      end

      describe '#inventory_units' do
        let(:product) { create(:product, stores: [subject]) }
        let(:product_2) { create(:product, stores: [create(:store)]) }
        let!(:inventory_unit) { create(:inventory_unit, variant: product.master, order: order) }
        let!(:inventory_unit_2) { create(:inventory_unit, variant: product_2.master, order: order_2) }

        it { expect(subject.inventory_units).to eq([inventory_unit]) }
      end
    end

    describe '#store_credits' do
      let!(:store_credit) { create(:store_credit, store: subject) }
      let!(:store_credit_2) { create(:store_credit, store: create(:store)) }

      it { expect(subject.store_credits).to eq([store_credit]) }

      describe '#store_credit_events' do
        let!(:store_credit_event) { store_credit.store_credit_events.first }
        let!(:store_credit_event_2) { store_credit_2.store_credit_events.first }

        it { expect(store_credit_event).not_to be_nil }
        it { expect(store_credit_event_2).not_to be_nil }
        it { expect(subject.store_credit_events).to eq([store_credit_event]) }
      end
    end

    describe '#menus' do
      let!(:menu) { create(:menu, store: subject) }
      let!(:menu_2) { create(:menu, store: create(:store)) }

      it { expect(subject.menus).to eq([menu]) }

      describe '#menu_items' do
        let!(:menu_item) { menu.menu_items.first }
        let!(:menu_item_2) { menu_2.menu_items.first }

        it { expect(subject.menu_items).to eq([menu_item]) }
      end
    end

    describe '#taxonomies' do
      let!(:taxonomy) { create(:taxonomy, store: subject) }
      let!(:taxonomy_2) { create(:taxonomy, store: create(:store)) }

      it { expect(subject.taxonomies).to eq([taxonomy]) }

      describe '#taxons' do
        let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
        let!(:taxon_2) { create(:taxon, taxonomy: taxonomy_2) }

        it { expect(taxon).not_to be_nil }
        it { expect(taxon_2).not_to be_nil }
        it { expect(subject.taxons).to match_array([taxonomy.root, taxon]) }
      end
    end

    describe '#promotions' do
      let!(:promotion) { create(:promotion, stores: [subject, create(:store)]) }
      let!(:promotion_2) { create(:promotion, stores: [create(:store)]) }

      it { expect(subject.promotions).to eq([promotion]) }
    end
  end

  describe 'validations' do
    describe 'code uniqueness' do
      context 'selected code was already used in a deleted store' do
        let(:store_code) { 'store_code' }

        let!(:default_store) { create(:store) }
        let!(:deleted_store) { create(:store, code: store_code).destroy! }

        it 'does not cause error related to unique constrains in DB' do
          expect { create(:store, code: store_code) }.not_to raise_error(ActiveRecord::RecordNotUnique)
        end

        it 'shows accurate validation error' do
          expect { create(:store, code: store_code) }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Code has already been taken')
        end
      end
    end
  end

  describe '.by_url' do
    let!(:store)    { create(:store, url: "website1.com\nwww.subdomain.com") }
    let!(:store_2)  { create(:store, url: 'freethewhales.com') }

    it 'finds stores by url' do
      by_domain = Spree::Store.by_url('www.subdomain.com')

      expect(by_domain).to include(store)
      expect(by_domain).not_to include(store_2)
    end
  end

  describe '.current' do
    # there is a default store created with the test_app rake task.
    let!(:store_1) { Spree::Store.first || create(:store) }

    let!(:store_2) { create(:store, default: false, url: 'www.subdomain.com') }

    it 'returns default when no domain' do
      expect(subject.class.current).to eql(store_1)
    end

    it 'returns store for domain' do
      expect(subject.class.current('spreecommerce.com')).to eql(store_1)
      expect(subject.class.current('www.subdomain.com')).to eql(store_2)
    end
  end

  describe '.default' do
    context 'when a default store is already present' do
      let!(:store)    { create(:store) }
      let!(:store_2)  { create(:store, default: true) }

      it 'returns the already existing default store' do
        expect(Spree::Store.default).to eq(store_2)
      end

      it "ensures there is a default if one doesn't exist yet" do
        expect(store_2.default).to be true
      end

      it 'ensures there is only one default' do
        [store, store_2].each(&:reload)

        expect(Spree::Store.where(default: true).count).to eq(1)
        expect(store_2.default).to be true
        expect(store.default).not_to be true
      end

      context 'when store is not saved' do
        before do
          store.default = true
          store.name = nil
          store.save
        end

        it 'ensure old default location still default' do
          [store, store_2].each(&:reload)
          expect(store.default).to be false
          expect(store_2.default).to be true
        end
      end
    end

    context 'when a default store is not present' do
      it 'builds a new default store' do
        described_class.delete_all
        Rails.cache.clear
        expect(described_class.default.class).to eq(described_class)
        expect(described_class.default.persisted?).to eq(false)
        expect(described_class.default.default).to be(true)
      end
    end
  end

  describe '.available_locales' do
    let!(:store) { create(:store, default_locale: 'en') }
    let!(:store_2) { create(:store, default_locale: 'de') }
    let!(:store_3) { create(:store, default_locale: 'en') }

    it { expect(described_class.available_locales).to contain_exactly('en', 'de') }
  end

  describe '.default_menu' do
    let!(:store_a) { create(:store, default_locale: 'en') }
    let!(:store_b) { create(:store, default_locale: 'en') }

    context 'when default menu is available' do
      let!(:menu_a) { create(:menu, store: store_a, locale: 'en') }
      let!(:menu_b) { create(:menu, store: store_a, locale: 'de') }

      it 'returns the default menu root' do
        expect(store_a.default_menu('header')).to eq(menu_a.root)
      end
    end

    context 'when default menu is not available' do
      let!(:menu_c) { create(:menu, store: store_b, locale: 'de') }
      let!(:menu_d) { create(:menu, store: store_b, locale: 'pl') }

      it 'returns the first created menu root' do
        expect(store_b.default_menu('header')).to eq(menu_c.root)
      end
    end
  end

  shared_context 'with checkout zone set' do
    let!(:country1) { create(:country) }
    let!(:country2) { create(:country) }

    let!(:state1)   { create(:state, country: country1) }
    let!(:state2)   { create(:state, country: country2) }

    let(:zone) do
      create(:zone, kind: 'country').tap do |zone|
        zone.members.create(zoneable: country1)
        zone.members.create(zoneable: country2)
      end
    end

    before { subject.update(checkout_zone: zone) }
  end

  shared_context 'with checkout zone not set' do
    before { subject.update(checkout_zone: nil) }
  end

  shared_context 'with default checkout zone set' do
    let!(:country3) { create(:country) }

    let!(:state3)   { create(:state, country: country3) }

    let(:default_zone) do
      Spree::Zone.first || create(:zone, kind: 'country').tap do |zone|
        zone.members.create(zoneable: country3)
      end
    end

    before { allow(Spree::Zone).to receive(:default_checkout_zone) { default_zone } }
  end

  shared_context 'with default checkout zone not set' do
    before { allow(Spree::Zone).to receive(:default_checkout_zone) { nil } }
  end

  describe '#countries_available_for_checkout' do
    subject { create(:store) }

    context do
      include_context 'with checkout zone set'

      it 'returns country list for checkout zone' do
        expect(subject.countries_available_for_checkout).to eq [country1, country2]
      end
    end

    context do
      include_context 'with checkout zone not set'

      it 'returns list of all countries' do
        checkout_available_countries_ids = subject.countries_available_for_checkout.ids
        all_countries_ids                = Spree::Country.all.ids

        expect(checkout_available_countries_ids).to eq(all_countries_ids)
      end
    end
  end

  describe '#states_available_for_checkout' do
    context do
      include_context 'with checkout zone set'

      it 'returns states list for checkout zone' do
        expect(subject.states_available_for_checkout(country1)).to eq [state1]
        expect(subject.states_available_for_checkout(country2)).to eq [state2]
      end
    end

    context do
      include_context 'with checkout zone not set'

      context do
        include_context 'with default checkout zone set'

        it 'returns states list for default checkout zone' do
          expect(subject.states_available_for_checkout(country3)).to eq [state3]
        end
      end

      context do
        include_context 'with default checkout zone not set'

        let(:country_with_states) do
          create(:country).tap do |country|
            country.states << create(:state)
          end
        end

        it 'returns list of states associated to country' do
          checkout_available_states_ids3 = subject.states_available_for_checkout(country_with_states).pluck(:id)
          all_countries_ids              = country_with_states.states.pluck(:id)

          expect(checkout_available_states_ids3).to eq(all_countries_ids)
        end
      end
    end
  end

  describe '#checkout_zone_or_default' do
    subject { described_class.new }

    context do
      include_context 'with checkout zone set'

      it 'returns checkout zone' do
        expect(subject.checkout_zone_or_default).to eq zone
      end
    end

    context do
      include_context 'with checkout zone not set'

      context do
        include_context 'with default checkout zone set'

        it 'returns default checkout zone' do
          expect(subject.checkout_zone_or_default).to eq default_zone
        end
      end

      context do
        include_context 'with default checkout zone not set'

        it 'returns nil' do
          expect(subject.checkout_zone_or_default).to be_nil
        end
      end
    end
  end

  describe '#ensure_default_country' do
    subject { build(:store) }

    let!(:default_country) { Spree::Country.first || create(:country) }
    let!(:other_country) { create(:country) }
    let!(:other_country_2) { create(:country) }

    context 'checkout zone not set' do
      before { subject.save! }

      context 'with default country' do
        before { subject.default_country = other_country }

        it { expect(subject.default_country).to eq(other_country) }
      end

      it { expect(subject.default_country).to eq(default_country) }
    end

    context 'checkout zone set' do
      let!(:zone) { create(:zone, kind: 'country') }

      before do
        zone.members.create(zoneable: other_country_2)
        subject.checkout_zone = zone
      end

      context 'with default country set' do
        before { subject.default_country = other_country }

        context 'no zone members' do
          before do
            zone.members.delete_all
            subject.save!
          end

          it { expect(subject.default_country).to eq(other_country) }
        end

        context 'default country is a zone member' do
          before do
            zone.members.create(zoneable: other_country)
            subject.save!
          end

          it { expect(subject.default_country).to eq(other_country) }
        end

        context 'default country is not a zone member' do
          before { subject.save! }

          it { expect(subject.default_country).to eq(other_country_2) }
        end
      end

      context 'without default country set' do
        context 'no zone members' do
          before do
            zone.members.delete_all
            subject.save!
          end

          it { expect(subject.default_country).to eq(default_country) }
        end

        context 'with zone members' do
          before { subject.save! }

          it { expect(subject.default_country).to eq(other_country_2) }
        end
      end
    end
  end

  describe '#unique_name' do
    let!(:store) { build(:store) }

    it 'returns the Store Name followed by the Store Code in parentheses' do
      expect(store.unique_name).to eq("#{store.name} (#{store.code})")
    end
  end

  describe '#supported_currencies_list' do
    context 'with supported currencies set' do
      let(:currencies) { 'USD, EUR, dummy' }
      let!(:store) { build(:store, default_currency: 'USD', supported_currencies: currencies) }

      it 'returns supported currencies list' do
        expect(store.supported_currencies_list).to contain_exactly(
          ::Money::Currency.find('EUR'), ::Money::Currency.find('USD')
        )
      end
    end

    context 'without supported currencies set' do
      let!(:store) { build(:store, default_currency: 'EUR', supported_currencies: nil) }

      it 'returns supported currencies list' do
        expect(store.supported_currencies_list).to contain_exactly(
          ::Money::Currency.find('EUR')
        )
      end
    end
  end

  describe '#supported_locales_list' do
    context 'with supported locale set' do
      let(:store) { build(:store, default_locale: 'fr', supported_locales: 'fr,de') }

      it 'returns supported currencies list' do
        expect(store.supported_locales_list).to be_an_instance_of(Array)
        expect(store.supported_locales_list).to contain_exactly('de', 'fr')
      end
    end

    context 'without supported currencies set' do
      let(:store) { build(:store, default_locale: nil, supported_locales: nil) }

      it 'returns supported currencies list' do
        expect(store.supported_locales_list).to be_an_instance_of(Array)
        expect(store.supported_locales_list).to be_empty
      end
    end
  end

  describe '#ensure_supported_locales' do
    context 'store with default_locale' do
      let(:store) { build(:store, default_locale: 'fr', supported_locales: nil) }

      it { expect { store.save! }.to change(store, :supported_locales).from(nil).to('fr') }
    end

    context 'store without default locale' do
      let(:store) { build(:store, default_locale: nil, supported_locales: nil) }

      it { expect { store.save! }.not_to change(store, :supported_locales).from(nil) }
    end

    context 'store with supported locales' do
      let(:store) { build(:store, default_locale: 'fr', supported_locales: 'fr,de') }

      it { expect { store.save! }.not_to change(store, :supported_locales) }
    end
  end

  describe '#ensure_supported_currencies' do
    context 'store with default_currency' do
      let(:store) { build(:store, default_currency: 'EUR', supported_currencies: nil) }

      it { expect { store.save! }.to change(store, :supported_currencies).from(nil).to('EUR') }
    end

    context 'store with supported currencies' do
      let(:store) { build(:store, default_currency: 'EUR', supported_currencies: 'EUR,GBP') }

      it { expect { store.save! }.not_to change(store, :supported_currencies) }
    end
  end

  describe '#favicon' do
    subject(:favicon) { store.favicon }

    context 'with an attached favicon image' do
      let(:store) { create(:store, :with_favicon) }
      let(:favicon_variation) { favicon.processed.variation }

      it 'returns a resized favicon' do
        expect(favicon_variation).to be_present
        expect(favicon_variation.transformations.fetch(:resize_to_limit)).to eq([32, 32])
      end
    end

    context 'without an attached favicon image' do
      let(:store) { create(:store) }

      it 'returns a blank favicon' do
        expect(favicon).to be(nil)
      end
    end
  end

  describe '#can_be_deleted?' do
    let(:default_store) { Spree::Store.default }

    it 'cannot delete the only store' do
      expect(default_store.can_be_deleted?).to eq(false)
    end

    it 'can delete when there are more than 1 stores' do
      create(:store)
      expect(default_store.can_be_deleted?).to eq(true)
    end
  end

  describe 'soft deletion' do
    let!(:default_store) { described_class.default }
    let(:another_store) { create(:store) }

    context 'default store' do
      context 'with multiple stores' do
        before { another_store }

        it 'can be deleted' do
          expect(default_store.deleted?).to eq(false)
          expect { default_store.destroy }.to change(default_store, :deleted_at)
          expect(default_store.deleted?).to eq(true)
        end

        it 'passes default flag to other store' do
          expect(another_store.default?).to eq(false)
          default_store.destroy
          expect(default_store.default?).to eq(false)
          expect(another_store.reload.default?).to eq(true)
          expect(described_class.default).to eq(another_store)
        end
      end

      context 'single store' do
        it 'cannot be deleted' do
          expect { default_store.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
          expect(default_store.errors.full_messages.to_sentence).to eq('Cannot destroy the only Store.')
        end
      end
    end

    context 'another store' do
      it 'soft-deletes when destroy is called' do
        another_store.destroy!
        expect(another_store.deleted_at).not_to be_nil
      end
    end

    context 'with associations' do
      before do
        another_store.products << create(:product)
      end

      it "doesn't destroy associations" do
        associations = described_class.reflect_on_all_associations(:has_many)
        expect(associations.select { |a| a.options[:dependent] }).to be_empty
      end
    end
  end
end
