require 'spec_helper'

describe Spree::Product, type: :model do
  let!(:store) { Spree::Store.default }

  describe 'normalizes :name' do
    it 'strips leading and trailing whitespace' do
      product = build(:product, name: '  Test Product  ', stores: [store])
      expect(product.name).to eq('Test Product')
    end

    it 'squishes multiple spaces' do
      product = build(:product, name: 'Test   Multiple   Spaces', stores: [store])
      expect(product.name).to eq('Test Multiple Spaces')
    end

    it 'converts empty string to nil' do
      product = build(:product, name: '   ', stores: [store])
      expect(product.name).to be_nil
    end

    it 'handles nil value' do
      product = build(:product, stores: [store])
      product.name = nil
      expect(product.name).to be_nil
    end

    context 'with always_use_translations enabled' do
      before do
        Spree::Config.always_use_translations = true
      end

      after do
        Spree::Config.always_use_translations = false
        I18n.locale = :en
      end

      it 'creates a product with translated name without NotNullViolation' do
        I18n.locale = :en
        product = create(:product, name: '  English Name  ', stores: [store])
        expect(product.name).to eq('English Name')
        expect(product.persisted?).to be true
      end

      it 'normalizes translated names across locales' do
        I18n.locale = :en
        product = create(:product, name: 'English Name', stores: [store])

        I18n.locale = :de
        product.name = '  German Name  '
        product.save!

        expect(product.name).to eq('German Name')

        I18n.locale = :en
        expect(product.name).to eq('English Name')
      end
    end
  end
end
