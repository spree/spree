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
        expect(store.contact_email).to eq('user@example.com')
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
end
