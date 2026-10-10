require 'spec_helper'

RSpec.describe Spree::ProductTypeCustomFieldDefinition, type: :model do
  let(:product_type) { create(:product_type) }

  describe 'validations' do
    it 'rejects a definition scoped to another resource' do
      order_definition = create(:custom_field_definition, :for_order)
      join = build(:product_type_custom_field_definition, product_type: product_type, custom_field_definition: order_definition)

      expect(join).not_to be_valid
      expect(join.errors[:custom_field_definition]).to include('must be a custom field definition for products')
    end

    it 'rejects a definition owned by another store' do
      foreign = create(:custom_field_definition, store: create(:store))
      join = build(:product_type_custom_field_definition, product_type: product_type, custom_field_definition: foreign)

      expect(join).not_to be_valid
      expect(join.errors[:custom_field_definition]).to include('must belong to the same store')
    end
  end

  describe 'scopes' do
    it '.required returns only required rows' do
      required = create(:product_type_custom_field_definition, :required, product_type: product_type)
      create(:product_type_custom_field_definition, product_type: product_type)

      expect(described_class.required).to eq([required])
    end

    it '.ordered sorts by sort_order' do
      second = create(:product_type_custom_field_definition, product_type: product_type, sort_order: 2)
      first = create(:product_type_custom_field_definition, product_type: product_type, sort_order: 1)

      expect(described_class.ordered).to eq([first, second])
    end
  end

  describe 'association from the product type' do
    it 'returns definitions in sort order' do
      later = create(:product_type_custom_field_definition, product_type: product_type, sort_order: 5)
      earlier = create(:product_type_custom_field_definition, product_type: product_type, sort_order: 1)

      expect(product_type.reload.custom_field_definitions).to eq(
        [earlier.custom_field_definition, later.custom_field_definition]
      )
    end
  end
end
