require 'spec_helper'

describe Spree::CustomFields::ShortText, type: :model do
  let(:product) { create(:product) }
  let(:custom_field_definition) { create(:custom_field_definition, :short_text_field, validations: { min: 2, max: 4 }) }

  def custom_field(value)
    described_class.new(custom_field_definition: custom_field_definition, value: value, resource: product)
  end

  describe 'length rules' do
    it 'checks the character count against min and max' do
      expect(custom_field('abc')).to be_valid
      expect(custom_field('a').tap(&:valid?).errors[:value]).to include(I18n.t('spree.errors.messages.custom_field_too_short', count: 2))
      expect(custom_field('abcde').tap(&:valid?).errors[:value]).to include(I18n.t('spree.errors.messages.custom_field_too_long', count: 4))
    end
  end
end
