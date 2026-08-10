require 'spec_helper'

RSpec.describe Spree::Calculator::Shipping::DigitalDelivery do
  subject { Spree::Calculator::Shipping::DigitalDelivery.new }

  it 'has a description for the class' do
    expect(Spree::Calculator::Shipping::DigitalDelivery).to respond_to(:description)
  end

  describe '#compute_package' do
    it 'quotes the package currency from the per-currency amounts' do
      subject.preferred_amounts = { 'EUR' => 3.5 }

      expect(subject.compute_package(double(currency: 'EUR'))).to eq(3.5)
    end

    it 'falls back to the legacy single amount for its own currency' do
      subject.preferred_amount = 2
      subject.preferred_currency = 'USD'

      expect(subject.compute_package(double(currency: 'USD'))).to eq(2)
      expect(subject.compute_package(double(currency: 'EUR'))).to be_nil
    end
  end

  describe '#available?' do
    let(:digital_shipping_method) { create(:digital_shipping_method) }
    let(:digital_product) { create(:digital_product) }

    let(:digital_order) do
      order = create(:order)
      variants = 3.times.map { create(:variant, digitals: [FactoryBot.create(:digital_asset)], product: digital_product) }
      package = Spree::Stock::Package.new(create(:stock_location), [])
      variants.each do |v|
        add_line_item_to_order(order, v, 1)
        order.rebuild_fulfillments!
        package.add(order.inventory_units.where(variant_id: v.id).first, 1)
      end
      package
    end

    let(:mixed_order) do
      order = create(:order)
      variants = 2.times.map { create(:variant, digitals: [FactoryBot.create(:digital_asset)], product: digital_product) }
      variants << create(:variant)
      package = Spree::Stock::Package.new(create(:stock_location), [])
      variants.each do |v|
        add_line_item_to_order(order, v, 1)
        order.rebuild_fulfillments!
        package.add(order.inventory_units.where(variant_id: v.id).first, 1)
      end
      package
    end

    let(:non_digital_order) do
      order = create(:order)
      variants = 3.times.map { create(:variant) }
      package = Spree::Stock::Package.new(create(:stock_location), [])
      variants.each do |v|
        add_line_item_to_order(order, v, 1)
        order.rebuild_fulfillments!
        package.add(order.inventory_units.where(variant_id: v.id).first, 1)
      end
      package
    end

    it 'returns true for a digital order' do
      expect(subject.available?(digital_order)).to be true
    end

    it 'returns false for a mixed order' do
      expect(subject.available?(mixed_order)).to be false
    end

    it 'returns false for an exclusively non-digital order' do
      expect(subject.available?(non_digital_order)).to be false
    end
  end

  def add_line_item_to_order(order, variant, quantity)
    Spree::Orders::AddItem.call(order: order, variant: variant, quantity: quantity)
  end
end
