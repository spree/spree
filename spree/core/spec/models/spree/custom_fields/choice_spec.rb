require 'spec_helper'

describe Spree::CustomFields::Choice, type: :model do
  let(:product) { create(:product) }

  context 'with a single choice' do
    let(:definition) { create(:custom_field_definition, :choice_field) }

    it 'stores one of the choices' do
      custom_field = product.set_custom_field(definition, 'b')

      expect(custom_field.value).to eq('b')
      expect(custom_field.serialize_value).to eq('b')
    end

    it 'refuses a value that is not a choice, or several values' do
      expect { product.set_custom_field(definition, 'z') }.to raise_error(ActiveRecord::RecordInvalid, /z/)
      expect { product.set_custom_field(definition, %w[a b]) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'with several choices allowed' do
    let(:definition) { create(:custom_field_definition, :multiple_choice_field) }

    it 'stores the values as a JSON array' do
      custom_field = product.set_custom_field(definition, %w[a c])

      expect(custom_field.value).to eq('["a","c"]')
      expect(custom_field.serialize_value).to eq(%w[a c])
      expect(custom_field.text_value).to eq('a, c')
      expect(custom_field.csv_value).to eq('a, c')
    end

    it 'accepts a single value as a list of one' do
      expect(product.set_custom_field(definition, 'a').serialize_value).to eq(['a'])
    end

    it 'refuses a list with a value that is not a choice' do
      expect { product.set_custom_field(definition, %w[a z]) }.to raise_error(ActiveRecord::RecordInvalid, /z/)
    end

    it 'keeps a value whose choice was removed readable until it is rewritten' do
      custom_field = product.set_custom_field(definition, %w[a c])
      definition.update!(validations: { choices: [{ value: 'a' }], multiple: true })

      expect(custom_field.reload).to be_valid
      expect(custom_field.serialize_value).to eq(%w[a c])
    end
  end
end
