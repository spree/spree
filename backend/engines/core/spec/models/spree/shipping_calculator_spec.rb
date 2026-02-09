require 'spec_helper'

module Spree
  describe ShippingCalculator, type: :model do
    subject { ShippingCalculator.new }

    let(:variant1) { build(:variant, price: 10) }
    let(:variant2) { build(:variant, price: 20) }
    let(:shipment) { build(:shipment) }

    let(:inventory_unit1) { build(:inventory_unit, quantity: 2, variant: variant1, line_item: line_item1) }
    let(:inventory_unit2) { build(:inventory_unit, quantity: 1, variant: variant2, line_item: line_item2) }
    let(:inventory_units) { [inventory_unit1, inventory_unit2] }

    let(:line_item1) { build(:line_item, variant: variant1, price: variant1.price) }
    let(:line_item2) { build(:line_item, variant: variant2, price: variant2.price) }

    let(:package) do
      build(:stock_package, contents: inventory_units.map { |iu| ::Spree::Stock::ContentItem.new(iu) })
    end

    it 'computes with a shipment' do
      expect(subject).to receive(:compute_shipment).with(shipment)
      subject.compute(shipment)
    end

    it 'computes with a package' do
      expect(subject).to receive(:compute_package).with(package)
      subject.compute(package)
    end

    it 'compute_shipment must be overridden' do
      expect do
        subject.compute_shipment(shipment)
      end.to raise_error(NotImplementedError)
    end

    it 'compute_package must be overridden' do
      expect do
        subject.compute_package(package)
      end.to raise_error(NotImplementedError)
    end

    it 'checks availability for a package' do
      expect(subject.available?(package)).to be true
    end

    it 'calculates totals for content_items' do
      expect(subject.send(:total, package.contents)).to eq 40.00
    end
  end
end
