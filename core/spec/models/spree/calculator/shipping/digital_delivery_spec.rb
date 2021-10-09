require 'spec_helper'

RSpec.describe Spree::Calculator::Shipping::DigitalDelivery do
  subject { Spree::Calculator::Shipping::DigitalDelivery.new }

  it 'has a description for the class' do
    expect(Spree::Calculator::Shipping::DigitalDelivery).to respond_to(:description)
  end

  describe '#compute_package' do
    it 'ignores the passed in object' do
      expect do
        subject.compute_package(double)
      end.not_to raise_error
    end

    it 'alwayses return the preferred_amount' do
      amount_double = double
      expect(subject).to receive(:preferred_amount).and_return(amount_double)
      expect(subject.compute_package(double)).to eq(amount_double)
    end
  end

  describe '#available?' do
    let(:digital_order) do
      order = create(:order)
      variants = 3.times.map { create(:variant, digitals: [FactoryBot.create(:digital)]) }
      package = Spree::Stock::Package.new(create(:stock_location), [])
      variants.each do |v|
        add_line_item_to_order(order, v, 1)
        order.create_proposed_shipments
        package.add(order.inventory_units.where(variant_id: v.id).first, 1)
      end
      package
    end

    let(:mixed_order) do
      order = create(:order)
      variants = 2.times.map { create(:variant, digitals: [FactoryBot.create(:digital)]) }
      variants << create(:variant)
      package = Spree::Stock::Package.new(create(:stock_location), [])
      variants.each do |v|
        add_line_item_to_order(order, v, 1)
        order.create_proposed_shipments
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
        order.create_proposed_shipments
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
    Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity)
  end
end
