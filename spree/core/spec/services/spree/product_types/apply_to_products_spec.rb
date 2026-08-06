require 'spec_helper'

RSpec.describe Spree::ProductTypes::ApplyToProducts do
  subject(:apply) { described_class.call(product_type: product_type) }

  let(:size) { create(:option_type, name: 'size') }
  let(:category) { create(:category) }
  let(:product_type) { create(:product_type) }

  describe 'option types' do
    before { product_type.option_types << size }

    it 'adds the missing option type to existing products' do
      product = create(:product)
      product.update_column(:product_type_id, product_type.id)

      expect(apply.value).to eq(1)
      expect(product.reload.option_types).to eq([size])
    end

    it 'keeps option types the product already had' do
      color = create(:option_type, name: 'color')
      product = create(:product, option_types: [color])
      product.update_column(:product_type_id, product_type.id)

      apply

      expect(product.reload.option_types).to match_array([color, size])
    end

    it 'continues each product position sequence' do
      color = create(:option_type, name: 'color')
      product = create(:product, option_types: [color])
      product.update_column(:product_type_id, product_type.id)

      apply

      positions = product.reload.product_option_types.order(:position).pluck(:option_type_id, :position)
      expect(positions).to eq([[color.id, 1], [size.id, 2]])
    end

    it 'leaves products of other types alone' do
      other_product = create(:product, product_type: create(:product_type))

      apply

      expect(other_product.reload.option_types).to be_empty
    end

    it 'is idempotent' do
      product = create(:product)
      product.update_column(:product_type_id, product_type.id)

      apply
      second_run = described_class.call(product_type: product_type)

      expect(second_run.value).to eq(0)
      expect(product.reload.option_types).to eq([size])
    end
  end

  describe 'categories' do
    before { product_type.categories << category }

    it 'adds the missing category to existing products' do
      product = create(:product)
      product.update_column(:product_type_id, product_type.id)

      expect(apply.value).to eq(1)
      expect(product.reload.categories).to eq([category])
    end

    it 'keeps the category products count correct' do
      product = create(:product)
      product.update_column(:product_type_id, product_type.id)

      apply

      expect(category.reload.products_count).to eq(1)
    end

    it 'does not duplicate an existing link' do
      product = create(:product, categories: [category])
      product.update_column(:product_type_id, product_type.id)

      apply

      expect(product.reload.categories).to eq([category])
      expect(category.reload.products_count).to eq(1)
    end
  end

  describe 'when the type defines nothing' do
    it 'reports no changes' do
      create(:product, product_type: product_type)

      expect(apply.value).to eq(0)
    end
  end

  it 'counts each product once when both option types and categories are added' do
    product_type.option_types << size
    product_type.categories << category
    product = create(:product)
    product.update_column(:product_type_id, product_type.id)

    expect(apply.value).to eq(1)
  end
end
