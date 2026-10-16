require 'spec_helper'

RSpec.describe Spree::Seeds::TaxExemptionReasons do
  let(:store) { @default_store }

  it 'keeps a reason the merchant renamed' do
    store.tax_exemption_reasons.create!(code: 'resale', name: 'Reseller (wholesale)')

    described_class.call(store: store)

    expect(store.tax_exemption_reasons.find_by(code: 'resale').name).to eq('Reseller (wholesale)')
    expect(store.tax_exemption_reasons.count).to eq(described_class::REASONS.size)
  end
end
