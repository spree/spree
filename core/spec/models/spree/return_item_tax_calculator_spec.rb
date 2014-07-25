require 'spec_helper'

describe Spree::ReturnItemTaxCalculator do

  let!(:tax_zone) { create(:zone, default_tax: true) }
  let!(:tax_rate) { nil }

  let(:order) { create(:shipped_order, line_items_count: 2) }
  let(:line_item_1) { order.line_items.first }
  let(:line_item_2) { order.line_items.last }
  let(:inventory_unit_1) { line_item_1.inventory_units.first }
  let(:inventory_unit_2) { line_item_2.inventory_units.first }

  let(:rma) { create(:return_authorization, order: order) }

  let(:return_items) { [return_item_1, return_item_2] }
  let(:return_item_1) { create(:return_item, pre_tax_amount: inventory_unit_1.pre_tax_amount, return_authorization: rma, inventory_unit: inventory_unit_1) }
  let(:return_item_2) { create(:return_item, pre_tax_amount: inventory_unit_2.pre_tax_amount, return_authorization: rma, inventory_unit: inventory_unit_2) }

  subject do
    Spree::ReturnItemTaxCalculator.call(return_items)
  end

  context 'without taxes' do
    let!(:tax_rate) { nil }

    it 'leaves the return items additional_tax_total and included_tax_total at zero' do
      subject

      expect(return_item_1.additional_tax_total).to eq 0
      expect(return_item_1.included_tax_total).to eq 0
    end
  end

  context 'with additional tax' do
    let!(:tax_rate) { create(:tax_rate, name: "Sales Tax", amount: 0.10, included_in_price: false, zone: tax_zone) }

    it 'sets additional_tax_total on the return items' do
      subject

      expect(return_item_1.additional_tax_total).to be > 0
      expect(return_item_1.additional_tax_total).to eq line_item_1.additional_tax_total
    end
  end

  context 'with included tax' do
    let!(:tax_rate) { create(:tax_rate, name: "VAT Tax", amount: 0.1, included_in_price: true, zone: tax_zone) }

    it 'sets included_tax_total on the return items' do
      subject

      expect(return_item_1.included_tax_total).to be < 0
      expect(return_item_1.included_tax_total).to eq line_item_1.included_tax_total
    end
  end
end
