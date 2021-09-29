require 'spec_helper'

describe Spree::Calculator::RelatedProductDiscount, type: :model do
  subject { described_class.new }

  describe '.description' do
    it 'outputs relation product discount' do
      expect(subject.description).to eq Spree.t(:related_product_discount)
    end
  end

  describe '.compute(object)' do
    it 'returns nil with empty Array' do
      expect(subject.compute([])).to be_nil
    end

    it 'returns 0 unless order is eligible' do
      empty_order = double('Spree::Order')
      allow(empty_order).to receive(:line_items).and_return([])
      expect(subject.compute(empty_order)).to be_zero
    end

    context 'with order with single item' do
      before do
        @order    = double('Spree::Order')
        product   = build(:product)
        variant   = double('Spree::Variant', product: product)
        price     = double('Spree::Price', variant: variant, amount: 5.00)
        line_item = double('Spree::LineItem', variant: variant, order: @order, quantity: 1, price: 4.99)

        allow(variant).to receive(:default_price).and_return(price)
        allow(variant).to receive(:product_id).and_return(product.id)
        allow(@order).to receive(:line_items).and_return([line_item])

        related_product = create(:product)
        relation_type   = create(:relation_type)

        create(:relation, relatable: product, related_to: related_product, relation_type: relation_type, discount_amount: 1.0)
      end

      it 'returns total count of Array' do
        objects = Array.new { @order }
        expect(subject.compute(objects)).to be_nil
      end

      it 'returns total count' do
        expect(subject.compute(@order)).to be_zero
      end
    end

    context 'with order with related items' do
      before do
        @order    = double('Spree::Order')
        product   = build_stubbed(:product)
        variant   = double('Spree::Variant', product: product)
        price     = double('Spree::Price', variant: variant, amount: 5.00)
        @line_item = double('Spree::LineItem', variant: variant, order: @order, quantity: 1, price: 4.99)
        @two_line_item = double('Spree::LineItem', variant: variant, order: @order, quantity: 2, price: 4.99)

        allow(variant).to receive(:default_price).and_return(price)
        allow(variant).to receive(:product_id).and_return(product.id)

        related_product = create(:product)
        related_variant   = double('Spree::Variant', product: related_product)
        related_price     = double('Spree::Price', variant: related_variant, amount: 5.00)
        @related_line_item = double('Spree::LineItem', variant: related_variant, order: @order, quantity: 1, price: 4.99)
        @two_related_line_item = double('Spree::LineItem', variant: related_variant, order: @order, quantity: 2, price: 4.99)

        allow(related_variant).to receive(:default_price).and_return(related_price)
        allow(related_variant).to receive(:product_id).and_return(related_product.id)

        related_product_2 = create(:product)
        relation_type   = create(:relation_type)

        create(:relation, relatable: product, related_to: related_product, relation_type: relation_type, discount_amount: 2.35)
        create(:relation, relatable: product, related_to: related_product_2, relation_type: relation_type, discount_amount: 0.0)
      end

      it 'returns total discount for one related item' do
        allow(@order).to receive(:line_items).and_return([@line_item, @related_line_item])
        expect(subject.compute(@order)).to eq 2.35
      end

      it 'returns total discount for 2 related items' do
        allow(@order).to receive(:line_items).and_return([@two_line_item, @two_related_line_item])
        expect(subject.compute(@order)).to eq 2*2.35
      end
    end

  end
end
