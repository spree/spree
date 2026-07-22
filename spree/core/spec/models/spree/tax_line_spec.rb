require 'spec_helper'

describe Spree::TaxLine, type: :model do
  it_behaves_like 'an adjustment line'

  describe '#included' do
    it 'defaults to false' do
      expect(described_class.new.included).to be(false)
    end
  end

  describe 'scopes' do
    let!(:included_line) { create(:tax_line, :included_in_price) }
    let!(:additional_line) { create(:tax_line) }
    let!(:fulfillment_line) { create(:tax_line, :for_fulfillment) }

    it 'partitions by included flag and adjustable side' do
      expect(described_class.included_in_price).to contain_exactly(included_line)
      expect(described_class.additional).to contain_exactly(additional_line, fulfillment_line)
      expect(described_class.for_line_items).to contain_exactly(included_line, additional_line)
      expect(described_class.for_fulfillments).to contain_exactly(fulfillment_line)
    end
  end

  describe 'prefixed id' do
    it 'uses the tl prefix' do
      expect(create(:tax_line).prefixed_id).to start_with('tl_')
    end
  end

  it 'resolves a soft-deleted tax rate' do
    tax_line = create(:tax_line)
    tax_line.tax_rate.destroy!

    expect(tax_line.reload.tax_rate).to be_present
  end
end
