require 'spec_helper'

RSpec.describe Spree::DefaultPrice do
  let(:store) { Spree::Store.default }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { product.master }

  describe 'with enable_legacy_default_price disabled (default)' do
    before do
      allow(Spree::Config).to receive(:enable_legacy_default_price).and_return(false)
    end

    describe '#price' do
      it 'returns amount from price_in for the default currency' do
        variant.set_price('USD', 29.99)
        expect(variant.price).to eq(29.99)
      end

      it 'returns nil when no price exists for the default currency' do
        variant.prices.destroy_all
        expect(variant.price).to be_nil
      end
    end

    describe '#price=' do
      it 'sets price via set_price' do
        variant.price = 19.99
        expect(variant.price_in('USD').amount).to eq(19.99)
      end
    end

    describe '#currency' do
      it 'returns the default store currency' do
        expect(variant.currency).to eq(store.default_currency)
      end
    end

    describe '#display_price' do
      it 'returns display amount for the default currency' do
        variant.set_price('USD', 10.55)
        expect(variant.display_price.to_s).to eq('$10.55')
      end
    end

    describe '#has_default_price?' do
      it 'returns true when a base price exists in the default currency' do
        variant.set_price('USD', 10)
        expect(variant.has_default_price?).to be true
      end

      it 'returns false when no base price exists in the default currency' do
        variant.prices.destroy_all
        expect(variant.has_default_price?).to be false
      end
    end

    describe '#set_price' do
      it 'persists the price when variant is persisted' do
        variant.set_price('USD', 42.00)
        expect(variant.price_in('USD').amount).to eq(42.00)
        expect(variant.price_in('USD')).to be_persisted
      end

      it 'builds price in-memory when variant is not persisted' do
        new_variant = Spree::Variant.new(product: product)
        new_variant.set_price('USD', 15.00)
        price = new_variant.prices.detect { |p| p.currency == 'USD' }
        expect(price.amount).to eq(15.00)
        expect(price).not_to be_persisted
      end

      it 'supports multiple currencies' do
        variant.set_price('USD', 29.99)
        variant.set_price('EUR', 27.99)
        expect(variant.price_in('USD').amount).to eq(29.99)
        expect(variant.price_in('EUR').amount).to eq(27.99)
      end
    end

    describe 'variant save without price' do
      it 'allows saving a variant without any price' do
        new_product = create(:product, stores: [store])
        master = new_product.master
        master.prices.destroy_all
        expect { master.save! }.not_to raise_error
      end
    end

    describe 'save_default_price callback' do
      it 'does not run' do
        variant.set_price('USD', 50.00)
        expect(variant).not_to receive(:save_default_price)
        variant.save!
      end
    end
  end

  describe 'with enable_legacy_default_price enabled' do
    before do
      allow(Spree::Config).to receive(:enable_legacy_default_price).and_return(true)
    end

    describe '#price' do
      it 'returns price from the default price record' do
        expect(variant.price).to eq(variant.default_price.amount)
      end
    end

    describe '#price=' do
      it 'sets price on the default price record' do
        variant.price = 25.00
        expect(variant.default_price.amount).to eq(25.00)
      end
    end

    describe '#has_default_price?' do
      it 'returns true when default_price exists' do
        expect(variant.has_default_price?).to be true
      end
    end

    describe 'save_default_price callback' do
      it 'saves the default price when it has changed' do
        variant.reload
        variant.default_price.price = 99.99
        expect(variant.default_price).to receive(:save)
        variant.save!
      end
    end

    describe 'check_price validation' do
      it 'runs the check_price validation' do
        new_variant = build(:variant, product: product)
        expect(new_variant).to be_valid
      end
    end
  end

  describe 'deprecation warnings' do
    it 'warns on #price' do
      expect(Spree::Deprecation).to receive(:warn).with(Spree::DefaultPrice::DEPRECATION_MSG).at_least(:once)
      variant.price
    end

    it 'warns on #price=' do
      expect(Spree::Deprecation).to receive(:warn).with(Spree::DefaultPrice::DEPRECATION_MSG).at_least(:once)
      variant.price = 10
    end

    it 'warns on #display_price' do
      expect(Spree::Deprecation).to receive(:warn).with(Spree::DefaultPrice::DEPRECATION_MSG).at_least(:once)
      variant.display_price
    end

    it 'warns on #currency' do
      expect(Spree::Deprecation).to receive(:warn).with(Spree::DefaultPrice::DEPRECATION_MSG).at_least(:once)
      variant.currency
    end

    it 'warns on #has_default_price?' do
      expect(Spree::Deprecation).to receive(:warn).with(Spree::DefaultPrice::DEPRECATION_MSG).at_least(:once)
      variant.has_default_price?
    end

    it 'warns on #find_or_build_default_price' do
      expect(Spree::Deprecation).to receive(:warn).with(Spree::DefaultPrice::DEPRECATION_MSG).at_least(:once)
      variant.find_or_build_default_price
    end
  end
end
