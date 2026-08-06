require 'spec_helper'

RSpec.describe Spree::DeliveryRateProvider::Internal do
  let(:store) { @default_store }
  let(:delivery_method) { create(:delivery_method, store: store) }
  let(:order) { create(:order_with_line_items, store: store) }
  let(:package) { order.fulfillments.first.to_package }

  subject(:provider) { described_class.new(delivery_method) }

  describe '#estimate' do
    it 'prices through the delivery method calculator' do
      allow(delivery_method.calculator).to receive(:compute).with(package).and_return(BigDecimal('12.5'))

      expect(provider.estimate(package).cost).to eq(BigDecimal('12.5'))
    end

    # The nil-suppresses-the-method equivalence is what lets calculator
    # thresholds (FlatRate's min/max bounds) keep hiding methods.
    it 'returns nil when the calculator suppresses the method' do
      allow(delivery_method.calculator).to receive(:compute).and_return(nil)

      expect(provider.estimate(package)).to be_nil
    end

    # Core has no holiday calendar, so it must not invent a delivery date.
    it 'carries no carrier metadata and no delivery date' do
      delivery_method.update!(estimated_transit_business_days_min: 3)
      allow(delivery_method.calculator).to receive(:compute).and_return(BigDecimal('5'))

      estimate = provider.estimate(package)
      expect(estimate.carrier).to be_nil
      expect(estimate.estimated_delivery_date).to be_nil
    end
  end
end
