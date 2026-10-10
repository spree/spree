require 'spec_helper'

describe Spree::OptionValue, type: :model do
  it_behaves_like 'metadata'

  describe 'callbacks' do
    describe '#normalize_name' do
      let!(:option_value) { build(:option_value, name: 'Red Color') }

      it 'should parameterize the name' do
        option_value.name = 'Red Color'
        option_value.valid?
        expect(option_value.name).to eq('red-color')
      end
    end

    describe '#touch_all_variants' do
      let!(:option_value) { create(:option_value) }
      let!(:variant1) { create(:variant, option_values: [option_value]) }
      let!(:variant2) { create(:variant, option_values: [option_value]) }

      it 'touches all variants associated with the option value' do
        Timecop.travel Time.current + 1.day do
          expect { option_value.send(:touch_all_variants) }.to change { [variant1.reload.updated_at, variant2.reload.updated_at] }
        end
      end
    end

    describe '#touch_all_products' do
      let!(:option_value) { create(:option_value) }
      let!(:product1) { create(:product) }
      let!(:product2) { create(:product) }
      let!(:product3) { create(:product) }

      before do
        create(:variant, product: product1, option_values: [option_value])
        create(:variant, product: product2, option_values: [option_value])
        create(:variant, product: product3)
      end

      it 'touches all products associated with the option value' do
        expect { option_value.send(:touch_all_products) }.to change { [product1.reload.updated_at, product2.reload.updated_at, product3.reload.updated_at] }
      end
    end
  end

  describe 'color_code validation' do
    it 'accepts 6- and 8-digit hex colors in any case, or no color' do
      ['#FF0000', '#FF0000AA', '#aabbcc', nil, ''].each do |valid|
        option_value = build(:option_value, color_code: valid)
        expect(option_value).to be_valid, "Expected #{valid.inspect} to be valid"
      end
    end

    it 'rejects invalid hex colors' do
      %w[FF0000 #FFF #GGGGGG red #FF00].each do |invalid|
        option_value = build(:option_value, color_code: invalid)
        expect(option_value).not_to be_valid, "Expected #{invalid.inspect} to be invalid"
        expect(option_value.errors[:color_code]).to be_present
      end
    end
  end

  describe 'translations' do
    let!(:option_value) { create(:option_value, name: 'red', label: 'Red') }

    before do
      Mobility.with_locale(:pl) do
        option_value.update!(label: 'Czerwony')
      end
    end

    describe '#label' do
      it 'returns the translated label for the current locale' do
        expect(option_value.label).to eq('Red')
      end

      it 'returns the translated label for a different locale' do
        Mobility.with_locale(:pl) do
          expect(option_value.label).to eq('Czerwony')
        end
      end

      it 'sets the translated label' do
        Mobility.with_locale(:pl) do
          option_value.label = 'Nowy Czerwony'
          option_value.save!
          expect(option_value.label).to eq('Nowy Czerwony')
        end
      end
    end
  end
end
