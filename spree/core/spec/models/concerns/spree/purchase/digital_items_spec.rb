require 'spec_helper'

RSpec.shared_examples 'a digital items host' do
  let(:digital_product) { create(:digital_product) }

  def digital_variant
    create(:variant, digitals: [create(:digital_asset)], product: digital_product)
  end

  context 'line_item analysis' do
    it 'understands that all products are digital' do
      3.times { add_line_item(record, digital_variant, 1) }
      expect(record.digital?).to be true

      add_line_item(record, digital_variant, 4)
      expect(record.digital?).to be true
    end

    it 'understands that no products are digital' do
      3.times { add_line_item(record, create(:variant), 1) }
      expect(record.digital?).to be false
    end

    it 'understands that an empty record is not digital' do
      expect(record.digital?).to be false
    end

    it 'understands that not all products are digital' do
      3.times { add_line_item(record, digital_variant, 1) }
      add_line_item(record, create(:variant, digitals: [create(:digital_asset)]), 1) # analog product with assets

      expect(record.digital?).to be false
    end
  end

  describe '#digital?/#some_digital?' do
    it 'returns true/true when every item is digital' do
      3.times { add_line_item(record, digital_variant, 1) }

      expect(record).to be_digital
      expect(record).to be_some_digital
    end

    it 'returns false/true for a mixed record' do
      2.times { add_line_item(record, digital_variant, 1) }
      add_line_item(record, create(:variant), 1)

      expect(record).not_to be_digital
      expect(record).to be_some_digital
    end

    it 'returns false/false for an exclusively non-digital record' do
      3.times { add_line_item(record, create(:variant), 1) }

      expect(record).not_to be_digital
      expect(record).not_to be_some_digital
    end
  end

  describe '#with_digital_assets? / #digital_line_items' do
    it 'detects items carrying digital assets' do
      expect(record.with_digital_assets?).to be false

      add_line_item(record, create(:variant), 1)
      add_line_item(record, digital_variant, 1)

      expect(record.with_digital_assets?).to be true
      expect(record.digital_line_items.count).to eq(1)
    end
  end

  describe '#digital_links' do
    let(:digital_assets) { 2.times.map { create(:digital_asset) } }

    it 'correctly loads the links' do
      digital_assets.each { |digital_asset| add_line_item(record, create(:variant, digital_assets: [digital_asset]), 1) }
      add_line_item(record, create(:variant), 1)

      links = record.digital_links
      links_from_digitals = digital_assets.map(&:reload).map(&:digital_links).flatten
      expect(links.size).to eq(links_from_digitals.size)
      links.each { |link| expect(links_from_digitals).to include(link) }
    end
  end

  describe '#delivery_step_required?' do
    it 'is false for an empty record — nothing to deliver yet' do
      expect(record.delivery_step_required?).to be false
    end

    it 'is false for an all-digital record — the provider fulfills without a selection' do
      add_line_item(record, digital_variant, 1)
      expect(record.delivery_step_required?).to be false
    end

    it 'is true once any item needs a delivery choice' do
      add_line_item(record, digital_variant, 1)
      add_line_item(record, create(:variant), 1)
      expect(record.delivery_step_required?).to be true
    end
  end
end

RSpec.describe Spree::Purchase::DigitalItems do
  let(:store) { @default_store }

  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: store) }

    def add_line_item(cart, variant, quantity)
      result = Spree::Carts::AddItem.call(cart: cart, variant: variant, quantity: quantity)
      raise result.error.to_s if result.failure?
    end

    it_behaves_like 'a digital items host'
  end

  context 'included in Spree::Order' do
    let(:record) { create(:order, store: store) }

    def add_line_item(order, variant, quantity)
      result = Spree::Orders::AddItem.call(order: order, variant: variant, quantity: quantity)
      raise result.error.to_s if result.failure?
    end

    it_behaves_like 'a digital items host'
  end
end
