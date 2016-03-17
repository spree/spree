require 'spec_helper'

describe Spree::Store, :type => :model do
  # there is a default store created with the test_app rake task.
  let(:store_1) { Spree::Store.where(default: true).first || create(:store) }
  let(:store_2) { create(:store, default: false) }

  describe 'callbacks' do
    it { is_expected.to callback(:ensure_default_exists_and_is_unique).before(:save) }
    it { is_expected.to callback(:validate_not_default).before(:destroy) }
    it { is_expected.to callback(:clear_cache).before(:save) }
    it { is_expected.to callback(:clear_cache).after(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:mail_from_address) }
  end

  describe 'associations' do
    it { is_expected.to have_many(:orders) }
  end

  describe 'scopes' do
    describe ".by_url" do
      let(:by_domain) { Spree::Store.by_url('www.subdomain.com') }

      before do
        store_1.update_column(:url, "website1.com\nwww.subdomain.com")
        store_2.update_column(:url, 'freethewhales.com')
      end
      it "should find stores by url" do
        expect(by_domain).to include(store_1)
        expect(by_domain).not_to include(store_2)
      end
    end
  end

  describe '.current' do
    before do
      store_2.update_column(:url, 'www.subdomain.com')
    end

    it 'should return default when no domain' do
      expect(subject.class.current).to eql(store_1)
    end

    it 'should return store for domain' do
      expect(subject.class.current('spreecommerce.com')).to eql(store_1)
      expect(subject.class.current('www.subdomain.com')).to eql(store_2)
    end
  end

  describe '.default' do
    context 'when a default store is already present' do
      before do
        store_1.update_column(:default, false)
        store_2.update_column(:default, true)
      end

      it 'should return the already existing default store' do
        expect(Spree::Store.default).to eq(store_2)
      end

      it "should ensure there is a default if one doesn't exist yet" do
        expect(store_2).to be_default
      end

      it 'should ensure there is only one default' do
        [store_1, store_2].each(&:reload)

        expect(Spree::Store.where(default: true).count).to eq(1)
        expect(store_2).to be_default
        expect(store_1).not_to be_default
      end

      context 'when store is not saved' do
        before do
          store_1.default = true
          store_1.code = nil
          store_1.save
        end

        it 'ensure old default location still default' do
          [store_1, store_2].each(&:reload)
          expect(store_1).not_to be_default
          expect(store_2).to be_default
        end
      end
    end

    context 'when a default store is not present' do
      let(:default_store) { Spree::Store.default }

      it 'should build a new default store' do
        expect(default_store.class).to eq(Spree::Store)
        expect(default_store).not_to be_persisted
        expect(default_store).to be_default
      end
    end
  end

  describe '.has_default?' do
    context 'when default store exists' do
      before { store_1.update_column(:default, true) }
      it { expect(Spree::Store.has_default?).to eq(true) }
    end

    context 'when default store does not exist' do
      before { Spree::Store.destroy_all }
      it { expect(Spree::Store.has_default?).to eq(false) }
    end
  end

  describe '#remove_previous_default' do
    before do
      store_1.update_column(:default, true)
      store_1.send(:remove_previous_default)
    end

    it { expect(Spree::Store.where(default: true)).to eq([store_1]) }
  end

  describe '#validate_not_default' do
    before do
      store_1.update_column(:default, true)
      store_1.send(:validate_not_default)
    end

    it 'adds error to store base' do
      expect(store_1.errors[:base]).to include(I18n.t(:cannot_destroy_default_store,
        scope: [:activerecord, :errors, :models, 'spree/store', :attributes, :base]))
    end
  end
end
