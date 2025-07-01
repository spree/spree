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

  describe '.to_tom_select_json' do
    let!(:option_value) { create(:option_value, name: 'red', presentation: 'Red') }
    let!(:option_value2) { create(:option_value, name: 'blue', presentation: 'Blue') }
    let!(:option_value3) { create(:option_value, name: 'green', presentation: 'Green') }

    it 'returns the option values in the correct format' do
      expect(Spree::OptionValue.to_tom_select_json).to eq([{ id: 'red', name: 'Red' }, { id: 'blue', name: 'Blue' }, { id: 'green', name: 'Green' }])
    end
  end

  describe 'translations' do
    let!(:option_value) { create(:option_value, name: 'red', presentation: 'Red') }

    before do
      Mobility.with_locale(:pl) do
        option_value.update!(presentation: 'Czerwony')
      end
    end

    let(:option_value_pl_translation) { option_value.translations.find_by(locale: 'pl') }

    it 'translates option value fields' do
      expect(option_value.presentation).to eq('Red')

      expect(option_value_pl_translation).to be_present
      expect(option_value_pl_translation.presentation).to eq('Czerwony')
    end
  end
end
