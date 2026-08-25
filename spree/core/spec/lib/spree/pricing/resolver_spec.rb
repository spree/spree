require 'spec_helper'

# The pre-6.0 entry point for pricing a variant. Kept working for one release
# because host apps and extensions called it directly.
describe Spree::Pricing::Resolver do
  let(:store) { @default_store }
  let(:variant) { create(:variant, price: 12) }
  let(:context) { Spree::Pricing::Context.new(variant: variant, currency: 'USD', store: store) }

  it 'still answers the catalog price' do
    allow(Spree::Deprecation).to receive(:warn)

    price = described_class.new(context).resolve

    expect(price.amount).to eq(12)
  end

  it 'warns that it has moved' do
    expect(Spree::Deprecation).to receive(:warn).with(/Spree::Pricing::Resolver is deprecated.*PriceResolution/m)

    described_class.new(context).resolve
  end

  it 'exposes the context it was built with' do
    expect(described_class.new(context).context).to eq(context)
  end
end
