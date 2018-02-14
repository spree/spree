require 'spec_helper'

module Spree
  describe ShippingCalculator, type: :model do
    subject { ShippingCalculator.new }

    let(:variant1) { build(:variant, price: 10) }
    let(:variant2) { build(:variant, price: 20) }

    let(:package) do
      build(:stock_package, variants_contents: { variant1 => 2, variant2 => 1 })
    end

    it 'computes with a shipment' do
      shipment = mock_model(Spree::Shipment)
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
      end.to raise_error(NameError)
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
