require 'spec_helper'

describe Spree::OptionValueVariant, type: :model do
  let(:option_value_variant) { create(:option_value_variant) }

  describe 'touching' do
    let(:variant) { option_value_variant.variant }

    it 'touches a variant' do
      expect(variant).to receive(:touch)
      option_value_variant.touch
    end
  end
end
