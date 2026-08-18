require 'spec_helper'

describe Spree::StoreCreditCategory do
  it 'warns that the class is a deprecated shell' do
    expect(Spree::Deprecation).to receive(:warn).with(/Spree::StoreCreditCategory is deprecated/)

    described_class.new(name: 'Goodwill')
  end

  it 'still answers default_refund_category, with a warning' do
    allow(Spree::Deprecation).to receive(:warn)
    category = described_class.create!(name: 'Goodwill')

    expect(Spree::Deprecation).to receive(:warn).with(/default_refund_category is deprecated/)
    expect(described_class.default_refund_category).to eq(category)
  end
end
