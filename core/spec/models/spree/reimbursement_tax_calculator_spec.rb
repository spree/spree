require 'spec_helper'

describe Spree::ReimbursementTaxCalculator do

  let!(:tax_rate) { nil }

  let(:reimbursement) { create(:reimbursement, reimbursement_items_count: 1) }
  let(:reimbursement_item) { reimbursement.reimbursement_items.first }
  let(:line_item) { reimbursement_item.inventory_unit.line_item }

  subject do
    Spree::ReimbursementTaxCalculator.call(reimbursement)
  end

  context 'without taxes' do
    let!(:tax_rate) { nil }

    it 'leaves the reimbursement items additional_tax_total and included_tax_total at zero' do
      subject

      expect(reimbursement_item.additional_tax_total).to eq 0
      expect(reimbursement_item.included_tax_total).to eq 0
    end
  end

  context 'with additional tax' do
    let!(:tax_rate) { create(:tax_rate, name: "Sales Tax", amount: 0.10, included_in_price: false, zone: tax_zone) }
    let(:tax_zone) { create(:zone, default_tax: true) }

    it 'sets additional_tax_total on the reimbursement items' do
      subject
      reimbursement_item.reload

      expect(reimbursement_item.additional_tax_total).to be > 0
      expect(reimbursement_item.additional_tax_total).to eq line_item.additional_tax_total
    end
  end

  context 'with included tax' do
    let!(:tax_rate) { create(:tax_rate, name: "VAT Tax", amount: 0.1, included_in_price: true, zone: tax_zone) }
    let(:tax_zone) { create(:zone, default_tax: true) }

    it 'sets included_tax_total on the reimbursement items' do
      subject
      reimbursement_item.reload

      expect(reimbursement_item.included_tax_total).to be < 0
      expect(reimbursement_item.included_tax_total).to eq line_item.included_tax_total
    end
  end
end
