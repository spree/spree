require 'spec_helper'

describe Spree::Store, type: :model, without_global_store: true do
  before(:all) do
    create(:country_us)
  end

  before do
    allow(Spree).to receive(:root_domain).and_return('mydomain.dev')
  end

  context 'Associations' do
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
    describe '#set_code' do
      let(:store) { build(:store, name: 'Store', code: nil) }

      it 'sets the code' do
        expect { store.valid? }.to change(store, :code).from(nil).to('store')
      end

      context 'when code is already set' do
        let(:store) { build(:store, name: 'Store', code: 'store') }

        it 'does not change the code' do
          expect { store.valid? }.not_to change(store, :code)
        end
      end

      context 'when name is not set' do
        let(:store) { build(:store, name: nil, code: nil) }

        it 'does not set the code' do
          expect { store.valid? }.not_to change(store, :code)
        end
      end

      context 'when code is already taken' do
        let(:default_store) { create(:store, default: true, code: 'store') }
        let(:store) { build(:store, name: 'Store', code: default_store.code) }

        it 'generates a new code' do
          expect { store.valid? }.to change(store, :code)
          expect(store.code).not_to eq(default_store.code)
          expect(store.code).to match(/store-\d+/)
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

    describe '#set_url' do
      let(:store) { build(:store, code: 'my_store', url: nil) }

      context 'on create' do
        it 'sets url' do
          store.save!
          expect(store.url).to eq('my_store.mydomain.dev')
        end
      end

      context 'on update code change update url' do
        let!(:store) { create(:store, code: 'my_store', url: 'my_store.mydomain.dev') }

        it 'updates url but keep old one' do
          expect(store.url).to eq('my_store.mydomain.dev')
          store.update!(code: 'my_store_2')
          expect(store.reload.url).to eq('my_store_2.mydomain.dev')
          expect(Spree::Store.friendly.find('my_store').id).to eq(store.id)
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

    describe '#ensure_default_post_categories_are_created' do
      let(:store) { build(:store) }

      it 'creates default post categories' do
        expect { store.save! }.to change(Spree::PostCategory, :count).by(3)

        expect(store.post_categories.count).to eq(3)
        expect(store.post_categories.pluck(:title)).to contain_exactly(
          Spree.t('default_post_categories.resources'),
          Spree.t('default_post_categories.articles'),
          Spree.t('default_post_categories.news')
        )
      end

      it 'is idempotent - does not create duplicates when called multiple times' do
        store.save!

        expect { store.send(:ensure_default_post_categories_are_created) }.not_to change(Spree::PostCategory, :count)
        expect(store.post_categories.count).to eq(3)
      end
    end

    describe '#import_products_from_store' do
      let(:store) { build(:store, import_products_from_store_id: other_store.id) }
      let(:other_store) { create(:store) }
      let!(:products) { create_list(:product, 2, stores: [other_store]) }

      it 'imports products from other store' do
        expect { store.save! }.to change(Spree::StoreProduct, :count).by(2)
        expect(store.products.count).to eq(2)

        expect(store.products.pluck(:id)).to match_array(products.pluck(:id))
      end
    end

    describe '#import_payment_methods_from_store' do
      let(:store) { build(:store, import_payment_methods_from_store_id: other_store.id) }
      let(:other_store) { create(:store) }
      let!(:payment_methods) { create_list(:payment_method, 2, stores: [other_store]) }

      it 'imports payment methods from other store' do
        expect { store.save! }.to change(Spree::StorePaymentMethod, :count).by(2)
        expect(store.payment_methods.count).to eq(2)
      end
    end
  end

  context 'Validations' do
    describe '#code' do
      let(:default_store) { create(:store, default: true, code: 'store') }

      it 'cannot create 2 stores with the same code' do
        new_store = create(:store, name: default_store.code)
        expect(new_store.persisted?).to be(true)
        expect(new_store.code).not_to eq(default_store.code) # code is generated
      end

      it 'cannot create a store with reserved code' do
        new_store = build(:store, code: 'admin')
        expect(new_store.valid?).to be(false)
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
      expect(Spree::Stores::FindCurrent.new(url: 'spreecommerce.com').execute).to eql(store_1)
      expect(Spree::Stores::FindCurrent.new(url: 'www.subdomain.com').execute).to eql(store_2)
    end
  end

  describe '.default' do
    context 'when a default store is already present' do
      let!(:store)    { create(:store) }
      let!(:store_2)  { create(:store, default: true) }

      it 'returns the already existing default store' do
        expect(described_class.default).to eq(store_2)
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
      before do
        described_class::Translation.delete_all
        described_class.delete_all
        Rails.cache.clear
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
    let!(:store) { create(:store, default_locale: 'en') }
    let!(:store_2) { create(:store, default_locale: 'de') }
    let!(:store_3) { create(:store, default_locale: 'en') }

    it { expect(described_class.available_locales).to contain_exactly('en', 'de') }
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
        checkout_available_countries_ids = subject.countries_available_for_checkout.pluck(:id)
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
    subject { build(:store) }

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

  describe '#default_country_iso=' do
    let(:store) { build(:store) }

    context 'when country is not found' do
      it 'sets the default country' do
        expect(Spree::Country.find_by(iso: 'GB')).to be_nil
        expect { store.default_country_iso = 'GB' }.to change(Spree::Country, :count).by(1)
        expect(store.default_country).to be_an_instance_of(Spree::Country)
        expect(store.default_country.iso).to eq('GB')
        expect(store.default_country.numcode.to_s).to eq(::Country['GB'].number)
        expect(store.default_country_iso).to eq('GB')
      end
    end

    context 'when country is found' do
      let!(:country) { create(:country, iso: 'GB') }

      it 'sets the default country' do
        expect { store.default_country_iso = 'GB' }.not_to change(Spree::Country, :count)
        expect(store.default_country.iso).to eq('GB')
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
      let(:store) { build(:store) }

      it 'returns a blank favicon' do
        expect(favicon).to be_nil
      end
    end
  end

  describe '#can_be_deleted?' do
    let(:default_store) { create(:store, default: true) }

    it 'cannot delete the only store' do
      expect(default_store.can_be_deleted?).to eq(false)
    end

    it 'can delete when there are more than 1 stores' do
      create(:store)
      expect(default_store.can_be_deleted?).to eq(true)
    end
  end

  describe 'soft deletion' do
    let!(:default_store) { create(:store, default: true) }
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

  describe '#supported_shipping_zones' do
    context 'with checkout zone set' do
      let!(:checkout_zone) { create(:zone) }

      subject { build(:store, checkout_zone: checkout_zone) }

      it 'returns the checkout zone' do
        expect(subject.supported_shipping_zones).to eq([checkout_zone])
      end
    end

    context 'when checkout zone not set' do
      it 'returns all shipping zones' do
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

    context 'without custom domain' do
      it { expect(store.formatted_url_or_custom_domain).to eq('http://mystore.mydomain.dev:3000') }
    end

    context 'with custom domain' do
      let!(:custom_domain) { create(:custom_domain, store: store, url: 'mystore.com') }

      it { expect(store.formatted_url_or_custom_domain).to eq('http://mystore.com:3000') }
    end
  end
end
