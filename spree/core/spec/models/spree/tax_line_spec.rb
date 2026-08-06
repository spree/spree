require 'spec_helper'

describe Spree::TaxLine, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }

  it 'is valid on a line item' do
    tax_line = described_class.new(order: order, line_item: line_item, amount: 1, rate: 0.1, label: 'VAT')
    expect(tax_line).to be_valid
  end

  it 'accepts a fee as adjustable' do
    fee = create(:fee, order: order)
    tax_line = described_class.new(order: order, fee: fee, amount: 0.4, rate: 0.2, label: 'VAT')
    expect(tax_line).to be_valid
    expect(tax_line.adjustable).to eq(fee)
  end

  it 'requires exactly one adjustable' do
    tax_line = described_class.new(order: order, amount: 1, rate: 0.1, label: 'VAT')
    expect(tax_line).not_to be_valid

    tax_line.line_item = line_item
    tax_line.fulfillment = create(:fulfillment, order: order)
    expect(tax_line).not_to be_valid
  end

  it 'stays meaningful without a tax rate' do
    tax_line = create(:tax_line, order: order, line_item: line_item, tax_rate: nil, provider_id: 'avalara', rate: 0.0825)
    expect(tax_line.reload.rate).to eq(0.0825)
    expect(tax_line.tax_rate).to be_nil
  end

  describe 'taxability reason' do
    subject(:tax_line) { described_class.new(order: order, line_item: line_item, amount: 0, rate: 0, label: 'VAT') }

    it 'accepts a core reason and nil' do
      tax_line.taxability_reason = 'reverse_charge'
      expect(tax_line).to be_valid

      tax_line.taxability_reason = nil
      expect(tax_line).to be_valid
    end

    it 'rejects a reason outside the vocabulary' do
      tax_line.taxability_reason = 'made_up'
      expect(tax_line).not_to be_valid
      expect(tax_line.errors[:taxability_reason]).to be_present
    end

    it 'accepts a reason registered after boot' do
      original = described_class.taxability_reasons
      described_class.taxability_reasons = original + ['margin_scheme']

      tax_line.taxability_reason = 'margin_scheme'
      expect(tax_line).to be_valid
    ensure
      described_class.taxability_reasons = original
    end
  end

  describe 'invoice codes' do
    subject(:tax_line) { described_class.new }

    it 'maps rated reasons to a category code without an exemption reason' do
      tax_line.taxability_reason = 'reduced_rated'
      expect(tax_line.category_code).to eq('S')
      expect(tax_line.exemption_reason_code).to be_nil
    end

    it 'maps cross-border reasons to both codes' do
      tax_line.taxability_reason = 'intra_community_supply'
      expect(tax_line.category_code).to eq('K')
      expect(tax_line.exemption_reason_code).to eq('VATEX-EU-IC')
    end

    it 'leaves an exempt supply without an exemption reason code' do
      tax_line.taxability_reason = 'product_exempt'
      expect(tax_line.category_code).to eq('E')
      expect(tax_line.exemption_reason_code).to be_nil
    end

    it 'has no code for a jurisdiction the merchant does not collect in' do
      tax_line.taxability_reason = 'not_collecting'
      expect(tax_line.category_code).to be_nil
    end

    it 'has no code without a reason' do
      expect(tax_line.category_code).to be_nil
    end
  end

  describe 'provider data' do
    it 'defaults to an empty hash so payloads read nil-safe' do
      expect(described_class.new.data).to eq({})
      expect(described_class.new.data['jurisdictions']).to be_nil
    end

    it 'round-trips a provider payload' do
      tax_line = create(:tax_line, order: order, line_item: line_item,
                                  data: { 'jurisdictions' => [{ 'name' => 'WA', 'amount' => '1.2' }] })
      expect(tax_line.reload.data['jurisdictions'].first['name']).to eq('WA')
    end
  end

  describe 'included vs additional' do
    let!(:included_line) { create(:tax_line, order: order, line_item: line_item, included: true) }
    let!(:additional_line) { create(:tax_line, order: order, line_item: line_item, included: false) }

    it 'partitions by the included flag' do
      expect(described_class.included_in_price).to contain_exactly(included_line)
      expect(described_class.additional).to contain_exactly(additional_line)
      expect(included_line).to be_included
      expect(additional_line).to be_additional
    end
  end
end
