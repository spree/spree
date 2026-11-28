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

    it 'stores a list of one as the bare value' do
      expect(product.set_custom_field(definition, %w[b]).value).to eq('b')
    end

    it 'reports a value that breaks the rules on the record that writes it' do
      new_product = build(:product, custom_fields: [{ custom_field_definition_id: definition.id, value: 'z' }])

      expect(new_product.save).to be(false)
      expect(new_product.errors['custom_fields[0].value']).to be_present
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

    it 'reads a CSV cell listing several choices back as a list' do
      expect(product.set_custom_field(definition, 'a, c').serialize_value).to eq(%w[a c])
    end

    it 'keeps a value that is itself a choice whole, even when it holds a comma' do
      definition.update!(validations: definition.validations.merge('choices' => definition.choices + [{ 'value' => 'a,c', 'label' => 'A and C' }]))

      expect(product.set_custom_field(definition, 'a,c').serialize_value).to eq(['a,c'])
    end

    it 'clears the field when given an empty list' do
      product.set_custom_field(definition, %w[a])

      expect(product.set_custom_field(definition, [])).to be_nil
      expect(product.custom_fields.count).to eq(0)
    end

    it 'turns off several choices when every value holds one, which then reads as that value' do
      custom_field = product.set_custom_field(definition, %w[a])

      expect(definition.update(validations: definition.validation_rules.except('multiple'))).to be(true)
      expect(custom_field.reload.serialize_value).to eq('a')
      expect(custom_field.value).to eq('a')
      expect(custom_field).to be_valid
    end

    it 'stores the values stripped and without repeats' do
      expect(product.set_custom_field(definition, [' a', 'a', 'c ']).value).to eq('["a","c"]')
    end

    it 'refuses to turn off several choices while a value holds several' do
      product.set_custom_field(definition, %w[a c])

      expect(definition.update(validations: definition.validation_rules.except('multiple'))).to be(false)
      expect(definition.errors[:validations]).to be_present
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
