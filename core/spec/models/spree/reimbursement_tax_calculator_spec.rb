require 'spec_helper'

describe Spree::ReimbursementTaxCalculator, :type => :model do

  let!(:tax_rate) { nil }

  let(:reimbursement) { create(:reimbursement, return_items_count: 1) }
  let(:return_item) { reimbursement.return_items.first }
  let(:line_item) { return_item.inventory_unit.line_item }

  subject do
    Spree::ReimbursementTaxCalculator.call(reimbursement)
  end

  context 'without taxes' do
    let!(:tax_rate) { nil }

    it 'leaves the return items additional_tax_total and included_tax_total at zero' do
      subject

      expect(return_item.additional_tax_total).to eq 0
      expect(return_item.included_tax_total).to eq 0
    end
  end

  context 'with additional tax' do
    let!(:tax_rate) do
      create :tax_rate,
             name: "Sales Tax",
             amount: 0.10,
             included_in_price: false,
             tax_category: create(:tax_category),
             zone: create(:zone_with_country, default_tax: true)
    end

    it 'sets additional_tax_total on the return items' do
      subject
      return_item.reload

      expect(return_item.additional_tax_total).to be > 0
      expect(return_item.additional_tax_total).to eq line_item.additional_tax_total
    end
  end

  context 'with included tax' do
    let!(:tax_rate) do
      create :tax_rate,
             name: "VAT Tax",
             amount: 0.10,
             included_in_price: true,
             tax_category: create(:tax_category),
             zone: create(:zone_with_country, default_tax: true)
    end

    it 'sets included_tax_total on the return items' do
      subject
      return_item.reload

      expect(return_item.included_tax_total).to be > 0
      expect(return_item.included_tax_total).to eq line_item.included_tax_total
    end
  end
end
