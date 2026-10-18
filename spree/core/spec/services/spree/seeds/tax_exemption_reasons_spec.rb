require 'spec_helper'

RSpec.describe Spree::Seeds::TaxExemptionReasons do
  let(:store) { @default_store }

  it 'keeps a reason the merchant renamed' do
    store.tax_exemption_reasons.create!(code: 'resale', name: 'Reseller (wholesale)')

    described_class.call(store: store)

    expect(store.tax_exemption_reasons.find_by(code: 'RESALE').name).to eq('Reseller (wholesale)')
    expect(store.tax_exemption_reasons.count).to eq(described_class::REASONS.size)
  end

  it 'keeps a reason the merchant recoded' do
    store.tax_exemption_reasons.create!(code: 'G', name: 'Resale')

    expect { described_class.call(store: store) }.not_to raise_error
    expect(store.tax_exemption_reasons.find_by(name: 'Resale').code).to eq('G')
  end
end
