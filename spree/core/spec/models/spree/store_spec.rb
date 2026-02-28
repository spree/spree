require 'spec_helper'

describe Spree::Store, type: :model, without_global_store: true do
  before(:all) do
    Spree::Country.find_by(iso: 'US') || create(:country_us)
  end

  context 'Associations' do
    subject { create(:store) }

    describe '#products' do
      let!(:product) { create(:product, stores: [subject]) }
      let!(:product_2) { create(:product, stores: [create(:store)]) }

      it { expect(subject.products).to eq([product]) }

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
      let!(:order) { create(:order, store: subject, total: 100) }
      let!(:order_2) { create(:order, store: create(:store), total: 100) }

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

    describe '#promotions' do
      let!(:promotion) { create(:promotion, stores: [subject, create(:store)]) }
      let!(:promotion_2) { create(:promotion, stores: [create(:store)]) }

      it { expect(subject.promotions).to eq([promotion]) }
    end
  end

  context 'Callbacks' do
    describe '#set_default_code' do
      let(:store) { build(:store, name: 'Store', code: nil) }

      it 'sets the code to default when blank' do
        expect { store.valid? }.to change(store, :code).from(nil).to('default')
      end

      context 'when code is already set' do
        let(:store) { build(:store, name: 'Store', code: 'mycode') }

        it 'does not change the code' do
          expect { store.valid? }.not_to change(store, :code)
        end
      end

      describe '#create_default_policies' do
        let(:store) { build(:store) }

        it 'creates default policies' do
          expect { store.save! }.to change(Spree::Policy, :count).by(4)

          expect(store.policies.count).to eq(4)
          expect(store.policies.pluck(:name)).to contain_exactly(
            Spree.t('terms_of_service'),
            Spree.t('privacy_policy'),
            Spree.t('returns_policy'),
            Spree.t('shipping_policy')
          )
        end

        it 'is idempotent - does not create duplicates when called multiple times' do
          store.save!

          expect { store.send(:create_default_policies) }.not_to change(Spree::Policy, :count)
          expect(store.policies.count).to eq(4)
        end

        context 'with non-English store locale' do
          let(:store) { build(:store, default_locale: 'de') }

          before do
            I18n.backend.store_translations(:de, {
              spree: {
                terms_of_service: 'Nutzungsbedingungen',
                privacy_policy: 'Datenschutzrichtlinie',
                returns_policy: 'Rückgaberecht',
                shipping_policy: 'Versandrichtlinie'
              }
            })
          end

          it 'creates policies with translated names in store locale' do
            store.save!

            # Policies are created with the translated name in the base column
            expect(store.policies.pluck(:name)).to contain_exactly(
              'Nutzungsbedingungen',
              'Datenschutzrichtlinie',
              'Rückgaberecht',
              'Versandrichtlinie'
            )
          end
        end
      end
    end

    describe '#ensure_default_market' do
      context 'when default_country_iso is set with shipping coverage' do
        let(:country) { Spree::Country.first || create(:country) }
        let(:store) { build(:store) }

        before do
          zone = create(:zone, name: 'Test Zone', kind: 'country')
          zone.zone_members.create!(zoneable: country)
          create(:shipping_method, zones: [zone])
          store.default_country_iso = country.iso
        end

        it 'creates a default market named after the country' do
          expect { store.save! }.to change(Spree::Market, :count).by(1)

          market = store.markets.first
          expect(market.name).to eq(country.name)
          expect(market).to be_default
          expect(market.countries).to include(country)
        end

        it 'does not create a second market on re-run' do
          store.save!
          expect { store.send(:ensure_default_market) }.not_to change(Spree::Market, :count)
        end
      end

      context 'when default_country_iso is not set' do
        let(:store) { build(:store) }

        it 'does not create a market' do
          expect { store.save! }.not_to change(Spree::Market, :count)
        end
      end
    end

    describe '#ensure_default_taxonomies_are_created' do
      let(:store) { build(:store) }

      it 'creates default taxonomies' do
        expect { store.save! }.to change(Spree::Taxonomy, :count).by(3)

        expect(store.taxonomies.count).to eq(3)
        expect(store.taxonomies.pluck(:name)).to contain_exactly(
          Spree.t(:taxonomy_categories_name),
          Spree.t(:taxonomy_brands_name),
          Spree.t(:taxonomy_collections_name)
        )
      end

      it 'is idempotent - does not create duplicates when called multiple times' do
        store.save!

        expect { store.send(:ensure_default_taxonomies_are_created) }.not_to change(Spree::Taxonomy, :count)
        expect(store.taxonomies.count).to eq(3)
      end

      context 'with non-English store locale' do
        let(:store) { build(:store, default_locale: 'de') }

        before do
          # Add German translations for taxonomy names
          I18n.backend.store_translations(:de, {
            spree: {
              taxonomy_categories_name: 'Kategorien',
              taxonomy_brands_name: 'Marken',
              taxonomy_collections_name: 'Kollektionen'
            }
          })
        end

        it 'creates taxonomies with translated names in store locale' do
          store.save!

          # Taxonomies are created with the translated name in the base column
          expect(store.taxonomies.pluck(:name)).to contain_exactly('Kategorien', 'Marken', 'Kollektionen')
        end

        it 'falls back to English when translation is missing' do
          # Remove the German translation for categories
          I18n.backend.store_translations(:de, { spree: { taxonomy_categories_name: nil } })

          store.save!

          # Categories falls back to English, others use German
          expect(store.taxonomies.pluck(:name)).to include('Categories') # fallback to English
          expect(store.taxonomies.pluck(:name)).to include('Marken')
          expect(store.taxonomies.pluck(:name)).to include('Kollektionen')
        end
      end
    end

    describe '#ensure_default_automatic_taxons' do
      let(:store) { build(:store) }
      let(:collections_taxonomy) { store.taxonomies.with_matching_name(Spree.t(:taxonomy_collections_name)).first }

      it 'creates automatic taxons on the collections taxonomy' do
        expect { store.save! }.to change(Spree::Taxon.automatic, :count).by(2)

        expect(store.reload.taxons.automatic.count).to eq(2)
        expect(store.taxons.automatic.pluck(:name)).to contain_exactly('New arrivals', 'On sale')
        expect(store.taxons.automatic.pluck(:taxonomy_id).uniq).to contain_exactly(collections_taxonomy.id)
      end

      it 'is idempotent - does not create duplicates when called multiple times' do
        store.save!

        expect { store.send(:ensure_default_automatic_taxons) }.not_to change(Spree::Taxon.automatic, :count)
        expect(store.taxons.automatic.count).to eq(2)
      end
    end

  end

  context 'Validations' do
    describe '#code' do
      it 'requires code to be present' do
        store = build(:store, code: nil, name: nil)
        store.valid?
        # set_default_code sets it to 'default' if blank, so it should be valid
        expect(store.code).to eq('default')
      end
    end
  end

  context 'Translations' do
    let!(:store) { create(:store, name: 'Store EN') }

    before do
      ::Mobility.with_locale(:pl) do
        store.update!(
          name: 'Store PL',
          description: 'PL description'
        )
      end
    end

    let(:store_pl_translation) { store.translations.find_by(locale: 'pl') }

    it 'translates store fields' do
      expect(store.name).to eq('Store EN')

      expect(store_pl_translation).to be_present
      expect(store_pl_translation.name).to eq('Store PL')
    end
  end

  describe '.current' do
    let!(:store_1) { Spree::Store.first || create(:store) }

    it 'returns Spree::Current.store' do
      Spree::Current.store = store_1
      expect(subject.class.current).to eql(store_1)
    end

    it 'ignores url argument' do
      Spree::Current.store = store_1
      expect(subject.class.current('other-url.com')).to eql(store_1)
    end
  end

  describe '.default' do
    context 'when a default store is already present' do
      let!(:store_2) { create(:store, default: true) }

      before { Spree::Store.where.not(id: store_2.id).update_all(default: false) }

      it 'returns the already existing default store' do
        expect(described_class.default).to eq(store_2)
      end
    end

    context 'when a default store is not present' do
      before do
        described_class::Translation.delete_all
        described_class.delete_all
      end

      it 'builds a new default store' do
        expect(described_class.default.class).to eq(described_class)
        expect(described_class.default.default).to be(true)
      end

      it 'does not persist the original default store' do
        expect(described_class.default.persisted?).to eq(false)
      end
    end
  end

  describe '.available_locales' do
    let!(:store) { create(:store, default: true, default_locale: 'en', supported_locales: 'en,fr') }

    before do
      Spree::Store.where.not(id: store.id).update_all(default: false)
    end

    it 'returns the default store supported locales' do
      expect(described_class.available_locales).to contain_exactly('en', 'fr')
    end
  end

  describe '#countries_available_for_checkout' do
    subject { create(:store) }

    context 'with markets' do
      let!(:germany) { create(:country, name: 'Germany', iso: 'DE') }
      let!(:france) { create(:country, name: 'France', iso: 'FR') }

      before do
        create(:market, store: subject, countries: [germany], currency: 'EUR', default: true)
        create(:market, store: subject, countries: [france], currency: 'EUR')
      end

      it 'returns countries from all markets' do
        countries = subject.countries_available_for_checkout
        expect(countries.map(&:iso)).to contain_exactly('DE', 'FR')
      end
    end

    context 'without markets' do
      it 'returns list of all countries' do
        checkout_available_countries_ids = subject.countries_available_for_checkout.pluck(:id)
        all_countries_ids                = Spree::Country.all.ids

        expect(checkout_available_countries_ids).to eq(all_countries_ids)
      end
    end
  end

  describe '#states_available_for_checkout' do
    subject { create(:store) }

    let(:country_with_states) do
      create(:country).tap do |country|
        country.states << create(:state)
      end
    end

    it 'returns list of states associated to country' do
      checkout_available_states_ids = subject.states_available_for_checkout(country_with_states).pluck(:id)
      all_state_ids                 = country_with_states.states.pluck(:id)

      expect(checkout_available_states_ids).to eq(all_state_ids)
    end
  end

  describe '#default_country' do
    context 'with markets' do
      let!(:store) { create(:store) }
      let!(:germany) { create(:country, name: 'Germany', iso: 'DE') }
      let!(:france) { create(:country, name: 'France', iso: 'FR') }

      before do
        create(:market, store: store, countries: [germany, france], currency: 'EUR', default: true)
      end

      it 'derives from the default market' do
        expect(store.default_country).to eq(france) # France comes before Germany alphabetically
      end
    end

    context 'without markets' do
      let!(:country) { Spree::Country.first || create(:country) }
      let(:store) { build(:store) }

      before { store.write_attribute(:default_country_id, country.id) }

      it 'returns the store column value' do
        expect(store.default_country).to eq(country)
      end
    end
  end

  describe '#default_country_iso=' do
    let(:store) { build(:store) }

    context 'when country is not found in the database' do
      it 'creates the country from ISO3166 data' do
        expect(Spree::Country.find_by(iso: 'GB')).to be_nil
        expect { store.default_country_iso = 'GB' }.to change(Spree::Country, :count).by(1)

        gb_country = Spree::Country.find_by(iso: 'GB')
        expect(gb_country).to be_present
        expect(gb_country.numcode.to_s).to eq(::Country['GB'].number)
        expect(store.default_country_iso).to eq('GB')
      end
    end

    context 'when country exists in the database' do
      let!(:country) { create(:country, iso: 'GB') }

      it 'uses the existing country' do
        expect { store.default_country_iso = 'GB' }.not_to change(Spree::Country, :count)
        expect(store.default_country_iso).to eq('GB')
      end
    end

    context 'when iso is blank' do
      it 'does nothing' do
        store.default_country_iso = ''
        expect(store.instance_variable_get(:@default_country_for_market)).to be_nil
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
    context 'with markets' do
      let!(:store) { create(:store, default_currency: 'USD') }

      before do
        create(:market, store: store, currency: 'USD', default: true)
        create(:market, store: store, currency: 'EUR')
      end

      it 'derives currencies from markets' do
        expect(store.supported_currencies_list).to contain_exactly(
          ::Money::Currency.find('USD'), ::Money::Currency.find('EUR')
        )
      end

      it 'puts default currency first' do
        expect(store.supported_currencies_list.first.iso_code).to eq('USD')
      end
    end

    context 'without markets (legacy)' do
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

        it 'returns default currency only' do
          expect(store.supported_currencies_list).to contain_exactly(
            ::Money::Currency.find('EUR')
          )
        end
      end
    end
  end

  describe '#default_currency' do
    context 'with markets' do
      let!(:store) { create(:store, default_currency: 'USD') }

      before do
        create(:market, store: store, currency: 'EUR', default: true)
        create(:market, store: store, currency: 'GBP')
      end

      it 'delegates to default market' do
        expect(store.default_currency).to eq('EUR')
      end
    end

    context 'with markets but no default_currency on store column' do
      let!(:store) { create(:store, default_currency: 'USD') }

      before do
        create(:market, store: store, currency: 'GBP', default: true)
        store.update_column(:default_currency, nil)
      end

      it 'returns default market currency' do
        expect(store.default_currency).to eq('GBP')
      end
    end

    context 'without markets' do
      let(:store) { build(:store, default_currency: 'USD') }

      it 'returns the store column value' do
        expect(store.default_currency).to eq('USD')
      end
    end

    context 'without markets and no default_currency on store column' do
      let(:store) { build(:store, default_currency: nil) }

      it 'returns nil' do
        expect(store.default_currency).to be_nil
      end
    end
  end

  describe '#default_locale' do
    context 'with markets' do
      let!(:store) { create(:store, default_locale: 'en') }

      before do
        create(:market, store: store, default_locale: 'de', default: true)
        create(:market, store: store, default_locale: 'fr')
      end

      it 'delegates to default market' do
        expect(store.default_locale).to eq('de')
      end
    end

    context 'with markets but no default_locale on store column' do
      let!(:store) { create(:store, default_locale: nil) }

      before do
        create(:market, store: store, default_locale: 'fr', default: true)
      end

      it 'returns default market locale' do
        expect(store.default_locale).to eq('fr')
      end
    end

    context 'without markets' do
      let(:store) { build(:store, default_locale: 'en') }

      it 'returns the store column value' do
        expect(store.default_locale).to eq('en')
      end
    end

    context 'without markets and no default_locale on store column' do
      let(:store) { build(:store, default_locale: nil) }

      it 'returns nil' do
        expect(store.default_locale).to be_nil
      end
    end
  end

  describe '#supported_locales_list' do
    context 'with markets' do
      let!(:store) { create(:store, default_locale: 'en') }

      before do
        create(:market, store: store, default_locale: 'en', supported_locales: 'fr', default: true)
        create(:market, store: store, default_locale: 'de', supported_locales: nil)
      end

      it 'includes default_locale from each market even when not in supported_locales' do
        expect(store.supported_locales_list).to contain_exactly('de', 'en', 'fr')
      end
    end

    context 'without markets (legacy)' do
      context 'with supported locales set' do
        let(:store) { build(:store, default_locale: 'fr', supported_locales: 'fr,de') }

        it 'returns supported locales list' do
          expect(store.supported_locales_list).to contain_exactly('de', 'fr')
        end
      end

      context 'without supported locales set' do
        let(:store) { build(:store, default_locale: nil, supported_locales: nil) }

        it 'returns empty array' do
          expect(store.supported_locales_list).to be_empty
        end
      end
    end
  end

  describe '#default_market' do
    let!(:store) { create(:store) }

    context 'with a default market' do
      let!(:market) { create(:market, :default, store: store) }
      let!(:other_market) { create(:market, store: store) }

      it 'returns the default market' do
        expect(store.default_market).to eq(market)
      end
    end

    context 'without a default market' do
      let!(:market1) { create(:market, store: store, position: 2) }
      let!(:market2) { create(:market, store: store, position: 1) }

      it 'falls back to the first market by position' do
        expect(store.default_market).to eq(market2)
      end
    end

    context 'without any markets' do
      it 'returns nil' do
        expect(store.default_market).to be_nil
      end
    end
  end

  describe '#market_for_country' do
    let!(:store) { create(:store) }
    let!(:country) { create(:country) }
    let!(:market) { create(:market, store: store, countries: [country]) }

    it 'returns the market containing the country' do
      expect(store.market_for_country(country)).to eq(market)
    end

    it 'returns nil for a country not in any market' do
      other_country = create(:country)
      expect(store.market_for_country(other_country)).to be_nil
    end
  end

  describe '#countries_from_markets' do
    let!(:store) { create(:store) }
    let!(:country_a) { create(:country) }
    let!(:country_b) { create(:country) }
    let!(:country_c) { create(:country) }

    context 'with markets' do
      before do
        create(:market, :default, store: store, countries: [country_a, country_b], currency: 'USD')
        create(:market, store: store, countries: [country_c], currency: 'EUR')
      end

      it 'returns countries from all markets' do
        countries = store.countries_from_markets
        expect(countries.pluck(:iso)).to contain_exactly(country_a.iso, country_b.iso, country_c.iso)
      end

      it 'returns an ActiveRecord relation' do
        expect(store.countries_from_markets).to be_a(ActiveRecord::Relation)
      end

      it 'orders by name' do
        names = store.countries_from_markets.pluck(:name)
        expect(names).to eq(names.sort)
      end

      it 'does not include countries not in any market' do
        other_country = create(:country)
        expect(store.countries_from_markets.pluck(:iso)).not_to include(other_country.iso)
      end

      it 'does not duplicate countries shared across markets' do
        store.markets.last.countries << country_a rescue nil
        expect(store.countries_from_markets.where(iso: country_a.iso).count).to eq(1)
      end
    end

    context 'without markets' do
      it 'returns empty relation' do
        expect(store.countries_from_markets).to be_empty
      end
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
      let(:store) { build(:store) }

      it 'returns a blank favicon' do
        expect(favicon).to be_nil
      end
    end
  end

  describe 'soft deletion' do
    let!(:store) { create(:store) }

    it 'soft-deletes when destroy is called' do
      store.destroy!
      expect(store.deleted_at).not_to be_nil
    end
  end

  describe '#default_stock_location' do
    context 'with default stock location' do
      let!(:default_stock_location) { create(:stock_location, default: true) }

      it 'returns the default stock location' do
        expect(subject.default_stock_location).to eq(default_stock_location)
      end
    end

    context 'without default stock location' do
      it 'creates a new default stock location' do
        expect { subject.default_stock_location }.to change(Spree::StockLocation, :count).by(1)
        expect(subject.default_stock_location.default?).to eq(true)
        expect(subject.default_stock_location.country).to eq(subject.default_country)
        expect(subject.default_stock_location.name).to eq(Spree.t(:default_stock_location_name))
      end
    end
  end

  describe '#countries_with_shipping_coverage' do
    let(:store) { create(:store) }

    context 'with country-type zones with shipping methods' do
      let(:country1) { create(:country) }
      let(:country2) { create(:country) }
      let!(:zone) { create(:zone, kind: 'country') }

      before do
        zone.zone_members.create!(zoneable: country1)
        zone.zone_members.create!(zoneable: country2)
        create(:shipping_method, zones: [zone])
      end

      it 'returns countries from those zones' do
        result = store.countries_with_shipping_coverage
        expect(result).to include(country1, country2)
      end
    end

    context 'with state-type zones with shipping methods' do
      let(:country) { create(:country) }
      let(:state) { create(:state, country: country) }
      let!(:zone) { create(:zone, kind: 'state') }

      before do
        zone.zone_members.create!(zoneable: state)
        create(:shipping_method, zones: [zone])
      end

      it 'returns countries inferred from state-type zones' do
        result = store.countries_with_shipping_coverage
        expect(result).to include(country)
      end
    end

    context 'when zone has no shipping method' do
      let(:country) { create(:country) }
      let!(:zone) { create(:zone, kind: 'country') }

      before do
        zone.zone_members.create!(zoneable: country)
      end

      it 'does not include countries from that zone' do
        expect(store.countries_with_shipping_coverage).not_to include(country)
      end
    end

    context 'when no shipping zones exist' do
      before { Spree::Zone.delete_all }

      it 'returns empty relation' do
        expect(store.countries_with_shipping_coverage).to be_empty
      end
    end

    context 'when country appears in multiple zones' do
      let(:country) { create(:country) }
      let!(:zone1) { create(:zone, kind: 'country') }
      let!(:zone2) { create(:zone, kind: 'country') }

      before do
        zone1.zone_members.create!(zoneable: country)
        zone2.zone_members.create!(zoneable: country)
        create(:shipping_method, zones: [zone1])
        create(:shipping_method, zones: [zone2])
      end

      it 'deduplicates countries' do
        result = store.countries_with_shipping_coverage
        expect(result.where(id: country.id).count).to eq(1)
      end
    end
  end

  describe '#supported_shipping_zones' do
    context 'with checkout zone set' do
      let!(:checkout_zone) { create(:zone) }
      let(:store) { create(:store) }

      before { store.update_column(:checkout_zone_id, checkout_zone.id) }

      it 'returns the checkout zone and emits deprecation warning' do
        expect(Spree::Deprecation).to receive(:warn).with(/supported_shipping_zones is deprecated/)
        expect(store.supported_shipping_zones).to eq([checkout_zone])
      end
    end

    context 'when checkout zone not set' do
      it 'returns all shipping zones and emits deprecation warning' do
        expect(Spree::Deprecation).to receive(:warn).with(/supported_shipping_zones is deprecated/)
        expect(subject.supported_shipping_zones).to eq(Spree::Zone.includes(zone_members: :zoneable).all)
      end
    end
  end

  describe '#formatted_url' do
    let(:store) { build(:store, code: 'mystore', url: 'mystore.mydomain.dev') }

    it { expect(store.formatted_url).to eq('http://mystore.mydomain.dev:3000') }

    context 'url with port' do
      let(:store) { build(:store, code: 'mystore', url: 'localhost:3000') }

      it { expect(store.formatted_url).to eq('http://localhost:3000') }
    end

    context 'on production' do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production')) }

      it { expect(store.formatted_url).to eq('https://mystore.mydomain.dev') }
    end
  end

  describe '#formatted_url_or_custom_domain' do
    let(:store) { build(:store, code: 'mystore', url: 'mystore.mydomain.dev:3000') }

    it 'returns formatted_url as fallback' do
      expect(store.formatted_url_or_custom_domain).to eq('http://mystore.mydomain.dev:3000')
    end
  end

  describe '#url_or_custom_domain' do
    let(:store) { build(:store, code: 'mystore', url: 'mystore.mydomain.dev') }

    it 'returns url as fallback' do
      expect(store.url_or_custom_domain).to eq('mystore.mydomain.dev')
    end
  end
end
