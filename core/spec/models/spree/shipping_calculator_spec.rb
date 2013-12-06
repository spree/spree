require 'spec_helper'

module Spree
  describe ShippingCalculator do
    let(:variant1) { build(:variant, :price => 10) }
    let(:variant2) { build(:variant, :price => 20) }

    let(:line_item1) { build(:line_item, variant: variant1) }
    let(:line_item2) { build(:line_item, variant: variant2) }

    let(:package) do
      Stock::Package.new(
        build(:stock_location),
        mock_model(Order),
        [
          Stock::Package::ContentItem.new(line_item1, variant1, 2),
          Stock::Package::ContentItem.new(line_item2, variant2, 1)
        ]
      )
    end

    subject { ShippingCalculator.new }

    it 'computes with a shipment' do
      shipment = mock_model(Spree::Shipment)
      shipment.should_receive(:to_package).and_return(package)
      subject.should_receive(:compute_package).with(package)
      subject.compute(shipment.to_package)
    end

    it 'computes with a package' do
      subject.should_receive(:compute_package).with(package)
      subject.compute(package)
    end

    it 'compute must be overridden' do
      expect {
        subject.compute_package(package)
      }.to raise_error
    end

    it 'checks availability for a package' do
      subject.available?(package).should be_true
    end

    it 'calculates totals for content_items' do
      subject.send(:total, package.contents).should eq 40.00
    end
  end
end
