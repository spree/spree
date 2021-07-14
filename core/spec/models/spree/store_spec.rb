require 'spec_helper'

describe Spree::Store, type: :model do
  describe 'deleting' do
    let!(:default_store) { create(:store, default: true) }
    let!(:store) { create(:store, default: false) }

    before { create(:store, default: true) }

    it 'is soft deleted' do
      store.destroy!
      expect(store.deleted_at).not_to be_nil
    end

    context 'there is a store with the shared products' do
      let(:store2) { create(:store) }
      let(:shared_product) { build(:product) }
      let(:not_shared_product) { build(:product) }

      before do
        Spree::Config[:disable_store_presence_validation] = true
        store.products << shared_product
        store.products << not_shared_product
        store2.products << shared_product
      end

      it 'does not remove the shared products' do
        expect { store.destroy! }.to change { Spree::Product.without_deleted.reload.count }.by(-1).
          and change { store2.products.reload.count }.by(0).
          and change { not_shared_product.deleted? }.from(false).to(true)
      end
    end
  end
  describe 'validations' do
    describe 'favicon image' do
      it 'validates image properties' do
        expect(build(:store, :with_favicon, filepath: file_fixture('icon_256x256.png'))).to be_valid

        expect(build(:store, :with_favicon, filepath: file_fixture('icon_512x512.png'))).not_to be_valid
        expect(build(:store, :with_favicon, filepath: file_fixture('icon_256x256.gif'))).not_to be_valid
        expect(build(:store, :with_favicon, filepath: file_fixture('img_256x128.png'))).not_to be_valid
      end

      context 'file size' do
        let(:store) do
          store = build(:store)
          store.favicon_image.attach(io: file, filename: 'favicon.png')
          store
        end

        let(:file) { File.open(file_fixture('icon_256x256.png')) }

        before do
          allow(file).to receive(:size).and_return(size)
        end

        context 'when size is 1 megabyte' do
          let(:size) { 1.megabyte }

          it 'is valid' do
            expect(store.valid?).to be(true)
          end
        end

        context 'when size is over 1 megabyte' do
          let(:size) { 1.megabyte + 1 }

          it 'is invalid' do
            expect(store.valid?).to be(false)
          end
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
        expect(Spree::Store.default.class).to eq(Spree::Store)
        expect(Spree::Store.default.persisted?).to eq(false)
        expect(Spree::Store.default.default).to be(true)
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
      create(:zone, kind: 'country').tap do |zone|
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

      context do
        include_context 'with default checkout zone set'

        it 'returns country list for default checkout zone' do
          expect(subject.countries_available_for_checkout).to eq [country3]
        end
      end

      context do
        include_context 'with default checkout zone not set'

        it 'returns list of all countries' do
          checkout_available_countries_ids = subject.countries_available_for_checkout.pluck(:id)
          all_countries_ids                = Spree::Country.all.pluck(:id)

          expect(checkout_available_countries_ids).to eq(all_countries_ids)
        end
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

    let!(:default_country) { create(:country) }
    let!(:other_country) { create(:country) }
    let!(:other_country_2) { create(:country) }

    before { Spree::Config[:default_country_id] = default_country.id }

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
        expect(favicon_variation.transformations.fetch(:resize)).to eq('32x32')
      end
    end

    context 'without an attached favicon image' do
      let(:store) { create(:store) }

      it 'returns a blank favicon' do
        expect(favicon).to be(nil)
      end
    end
  end
end
