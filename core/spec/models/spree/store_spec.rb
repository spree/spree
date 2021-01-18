require 'spec_helper'

describe Spree::Store, type: :model do
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

    context 'when footer info is provided' do
      let!(:store) { create(:store, description: 'Some description', address: 'Address street 123, City 17', contact_phone: '123123123', contact_email: 'user@example.com') }

      it 'sets footer info fields' do
        expect(store.description).to eq('Some description')
        expect(store.address).to eq('Address street 123, City 17')
        expect(store.contact_phone).to eq('123123123')
      end
    end

    context '.unique_name' do
      let!(:store) { create(:store) }

      it 'returns the Store Name followed by the Store Code in parentheses' do
        expect(store.unique_name).to eq("#{store.name} (#{store.code})")
      end
    end

    describe '.supported_currencies_list' do
      context 'with supported currencies set' do
        let(:currencies) { 'USD, EUR, dummy' }
        let!(:store) { create(:store, default_currency: 'USD', supported_currencies: currencies) }

        it 'returns supported currencies list' do
          expect(store.supported_currencies_list).to contain_exactly(
            ::Money::Currency.find('USD'), ::Money::Currency.find('EUR')
          )
        end
      end

      context 'without supported currencies set' do
        let!(:store) { create(:store, default_currency: 'EUR', supported_currencies: nil) }

        it 'returns supported currencies list' do
          expect(store.supported_currencies_list).to contain_exactly(
            ::Money::Currency.find('EUR')
          )
        end
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
end
