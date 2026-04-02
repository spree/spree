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

  describe 'kind' do
    it 'defaults to dropdown' do
      option_type = create(:option_type)
      expect(option_type.kind).to eq('dropdown')
    end

    it 'validates inclusion in KINDS' do
      option_type = build(:option_type, kind: 'invalid')
      expect(option_type).not_to be_valid
      expect(option_type.errors[:kind]).to include('is not included in the list')
    end

    it 'allows dropdown, color_swatch, and buttons' do
      %w[dropdown color_swatch buttons].each do |kind|
        option_type = build(:option_type, kind: kind)
        expect(option_type).to be_valid
      end
    end

    it 'validates presence' do
      option_type = build(:option_type, kind: '')
      expect(option_type).not_to be_valid
    end
  end

  describe '#color_swatch?' do
    it 'returns true when kind is color_swatch' do
      option_type = build(:option_type, kind: 'color_swatch')
      expect(option_type.color_swatch?).to be true
    end

    it 'returns false when kind is dropdown' do
      option_type = build(:option_type, kind: 'dropdown')
      expect(option_type.color_swatch?).to be false
    end
  end

  describe '.color_swatches' do
    let!(:color_type) { create(:option_type, :color_swatch) }
    let!(:size_type) { create(:option_type, :size) }

    it 'returns only color_swatch option types' do
      expect(described_class.color_swatches).to include(color_type)
      expect(described_class.color_swatches).not_to include(size_type)
    end
  end

  describe 'color methods' do
    let!(:option_type) { create(:option_type, name: 'Color', kind: 'color_swatch') }

    describe '.color' do
      it 'should return the first option type with name "color"' do
        expect(described_class.color).to eq(option_type)
      end
    end

    describe '#color?' do
      it 'is deprecated and delegates to color_swatch?' do
        expect(Spree::Deprecation).to receive(:warn).with(/deprecated/)
        expect(option_type.color?).to be true
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
