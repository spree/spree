require 'spec_helper'

describe Spree::OptionType, type: :model do
  it_behaves_like 'metadata'

  describe '#filterable' do
    it { expect(subject.filterable).to eq(true) }
  end

  describe 'callbacks' do
    describe '#normalize_name' do
      let!(:option_type) { build(:option_type, name: 'Shirt Size') }

      it 'should parameterize the name' do
        option_type.name = 'Shirt Size'
        option_type.save!
        expect(option_type.name).to eq('shirt-size')
      end
    end
  end

  describe 'translations' do
    let!(:option_type) { create(:option_type, name: 'size', presentation: 'Size') }

    before do
      Mobility.with_locale(:pl) do
        option_type.update!(presentation: 'Rozmiar')
      end
    end

    let(:option_type_pl_translation) { option_type.translations.find_by(locale: 'pl') }

    it 'translates option type fields' do
      expect(option_type.presentation).to eq('Size')

      expect(option_type_pl_translation).to be_present
      expect(option_type_pl_translation.presentation).to eq('Rozmiar')
    end

    context 'with always_use_translations enabled' do
      before do
        Spree::Config.always_use_translations = true
      end

      after do
        Spree::Config.always_use_translations = false
        I18n.locale = :en
      end

      it 'creates option type with normalized presentation without NotNullViolation' do
        I18n.locale = :en
        option_type = create(:option_type, name: 'weight', presentation: '  Weight  ')
        expect(option_type.presentation).to eq('Weight')
        expect(option_type.persisted?).to be true
      end

      it 'normalizes translated presentations across locales' do
        I18n.locale = :en
        option_type = create(:option_type, name: 'material', presentation: 'Material')

        I18n.locale = :de
        option_type.presentation = '  Material German  '
        option_type.save!

        expect(option_type.presentation).to eq('Material German')

        I18n.locale = :en
        expect(option_type.presentation).to eq('Material')
      end
    end
  end

  describe 'color methods' do
    let!(:option_type) { create(:option_type, name: 'Color') }

    describe '.color' do
      it 'should return the first option type with name "color"' do
        expect(described_class.color).to eq(option_type)
      end
    end

    describe '#color?' do
      it 'should return true if the name is "color" or "colour"' do
        expect(option_type.color?).to be_truthy
      end

      it 'should return false if the name is not "color" or "colour"' do
        option_type.update(name: 'Size')
        expect(option_type.color?).to be_falsy
      end
    end
  end

  context 'touching' do
    let(:option_type) { create(:option_type) }
    let(:product) { create(:product) }
    let!(:product_option_type) { create(:product_option_type, option_type: option_type, product: product) }

    before do
      product.update_column(:updated_at, 1.day.ago)
    end

    it 'touches a product on touch' do
      expect { option_type.touch }.to change { product.reload.updated_at }
    end

    it 'touches a product on update' do
      expect { option_type.update!(presentation: 'New Presentation') }.to change { product.reload.updated_at }
    end
  end

  describe '#filter_param' do
    let!(:option_type) { create(:option_type, name: 'color', presentation: 'Color') }
    let!(:other_option_type) { create(:option_type, name: 'secondary color', presentation: 'Secondary Color') }
    let!(:some_option_type) { create(:option_type, name: 'option type', presentation: 'Some Option Type') }

    it 'returns filtered name param' do
      expect(option_type.filter_param).to eq('color')
      expect(other_option_type.filter_param).to eq('secondary-color')
      expect(some_option_type.filter_param).to eq('option-type')
    end
  end

  describe '#self.color' do
    let!(:option_type) { create(:option_type, name: 'color', presentation: 'Color') }

    it 'finds color option type' do
      Spree::OptionType.color.id == option_type.id
    end
  end
end
