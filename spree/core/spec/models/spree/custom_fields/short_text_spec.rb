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
      expect(custom_field('a').tap(&:valid?).errors[:value]).to include(I18n.t('spree.errors.messages.custom_field_too_short', bound: 2))
      expect(custom_field('abcde').tap(&:valid?).errors[:value]).to include(I18n.t('spree.errors.messages.custom_field_too_long', bound: 4))
    end
  end

  describe 'regex rule' do
    let(:custom_field_definition) { create(:custom_field_definition, :short_text_field, validations: { regex: '[A-Z]{3}-\\d{4}' }) }

    it 'requires the whole value to match' do
      mismatch = I18n.t('spree.errors.messages.custom_field_regex_mismatch')

      expect(custom_field('ABC-1234')).to be_valid
      expect(custom_field('xABC-1234').tap(&:valid?).errors[:value]).to include(mismatch)
      expect(custom_field("ABC-1234\nmore").tap(&:valid?).errors[:value]).to include(mismatch)
    end
  end
end
