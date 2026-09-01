require 'spec_helper'

RSpec.describe SpreeAvalara::EntityUseCodes do
  it 'holds the seventeen codes Avalara defines' do
    expect(described_class::ALL.size).to eq(17)
    expect(described_class::ALL['G']).to eq('RESALE')
    expect(described_class::ALL['TAXABLE']).to eq('NON-EXEMPT TAXABLE CUSTOMER')
  end

  describe '.for' do
    it 'passes a code Avalara already knows straight through' do
      expect(described_class.for('G')).to eq('G')
      expect(described_class.for('taxable')).to eq('TAXABLE')
    end

    it 'translates the names a merchant is likely to have recorded' do
      expect(described_class.for('RESALE')).to eq('G')
      expect(described_class.for('FEDERAL_GOV')).to eq('A')
      expect(described_class.for('federal gov')).to eq('A')
      expect(described_class.for('EDUCATIONAL_ORG')).to eq('N')
    end

    # A claim Avalara cannot classify is still a claim; dropping it would tax an
    # exempt buyer.
    it 'sends an unrecognized reason as OTHER/CUSTOM' do
      expect(described_class.for('SOMETHING_LOCAL')).to eq('L')
      expect(described_class).not_to be_recognized('SOMETHING_LOCAL')
    end

    it 'claims nothing when no reason was recorded' do
      expect(described_class.for(nil)).to be_nil
      expect(described_class.for('')).to be_nil
    end
  end
end
