require 'spec_helper'

describe Spree::Order, type: :model do
  context 'line_item analysis' do
    it 'understands that all products are digital' do
      order = create(:order)
      3.times do
        add_line_item_to_order(order, create(:variant, digitals: [create(:digital)]), 1)
      end
      expect(order.digital?).to be true
      add_line_item_to_order(order, create(:variant, digitals: [create(:digital)]), 4)
      expect(order.digital?).to be true
    end

    it 'understands that no products are digital' do
      order = create(:order)
      3.times do
        add_line_item_to_order(order, create(:variant), 1)
      end
      expect(order.digital?).to be false
    end

    it 'understands that empty order is not digital' do
      order = create(:order)
      expect(order.digital?).to be false
    end

    it 'understands that not all products are digital' do
      order = create(:order)
      3.times do
        add_line_item_to_order(order, create(:variant, digitals: [create(:digital)]), 1)
      end
      add_line_item_to_order(order, create(:variant), 1) # this is the analog product
      expect(order.digital?).to be false
      add_line_item_to_order(order, create(:variant, digitals: [create(:digital)]), 4)
      expect(order.digital?).to be false
    end
  end

  context 'Spree::Cart::AddItem.call' do
    it 'should add digital Variants of quantity 1 to an order' do
      order = create(:order)
      variants = 3.times.map { create(:variant, digitals: [create(:digital)]) }
      variants.each do |v|
        add_line_item_to_order(order, v, 1)
      end
      expect(order.line_items.first.variant).to eq(variants[0])
      expect(order.line_items.second.variant).to eq(variants[1])
      expect(order.line_items.third.variant).to eq(variants[2])
    end

    it 'should handle quantity higher than 1 when adding one specific digital Variant' do
      order = create(:order)
      digital_variant = create(:variant, digitals: [create(:digital)])
      add_line_item_to_order(order, digital_variant, 3)
      expect(order.line_items.first.quantity).to eq(3)
      add_line_item_to_order(order, digital_variant, 2)
      expect(order.line_items.first.quantity).to eq(5)
    end
  end

  context '#digital?/#some_digital?' do
    let(:digital_order) do
      order = create(:order)
      variants = 3.times.map { create(:variant, digitals: [create(:digital)]) }
      variants.each { |v| add_line_item_to_order(order, v, 1) }
      order
    end

    let(:mixed_order) do
      order = create(:order)
      variants = 2.times.map { create(:variant, digitals: [create(:digital)]) }
      variants << create(:variant)
      variants.each { |v| add_line_item_to_order(order, v, 1) }
      order
    end

    let(:non_digital_order) do
      order = create(:order)
      variants = 3.times.map { create(:variant) }
      variants.each { |v| add_line_item_to_order(order, v, 1) }
      order
    end

    it 'should return true/true for a digital order' do
      expect(digital_order).to be_digital
      expect(digital_order).to be_some_digital
    end

    it 'should return false/true for a mixed order' do
      expect(mixed_order).not_to be_digital
      expect(mixed_order).to be_some_digital
    end

    it 'should return false/false for an exclusively non-digital order' do
      expect(non_digital_order).not_to be_digital
      expect(non_digital_order).not_to be_some_digital
    end
  end

  describe '#digital_links' do
    let(:mixed_order_digitals) { 2.times.map { create(:digital) } }
    let(:mixed_order) do
      order = create(:order)
      variants = mixed_order_digitals.map { |d| create(:variant, digitals: [d]) }
      variants << create(:variant)
      variants.each { |v| add_line_item_to_order(order, v, 1) }
      order
    end

    it 'correctly loads the links' do
      mixed_order_digital_links = mixed_order.digital_links
      links_from_digitals = mixed_order_digitals.map(&:reload).map(&:digital_links).flatten
      expect(mixed_order_digital_links.size).to eq(links_from_digitals.size)
      mixed_order_digital_links.each do |l|
        expect(links_from_digitals).to include(l)
      end
    end
  end

  def add_line_item_to_order(order, variant, quantity)
    Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity)
  end
end
