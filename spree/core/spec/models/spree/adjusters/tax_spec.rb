require 'spec_helper'

describe Spree::Adjusters::Tax, type: :model do
  it 'declares the :tax type so it runs last in the pipeline' do
    expect(described_class.type).to eq(:tax)
  end

  it 'delegates to TaxRate.adjust once for all adjustables' do
    order = double(:order)
    adjustables = [double(:line_item), double(:shipment)]

    expect(Spree::TaxRate).to receive(:adjust).once.with(order, adjustables)

    described_class.adjust_all(order, adjustables)
  end
end
