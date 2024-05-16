require 'spec_helper'

describe Spree::OptionValue, type: :model do
  it_behaves_like 'metadata'

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

  context 'touching' do
    it 'touches a variant' do
      variant = create(:variant)
      option_value = variant.option_values.first
      variant.update_column(:updated_at, 1.day.ago)
      option_value.touch
      expect(variant.reload.updated_at).to be_within(3.seconds).of(Time.current)
    end
  end
end
