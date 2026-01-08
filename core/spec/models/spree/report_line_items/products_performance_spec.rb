require 'spec_helper'

RSpec.describe Spree::ReportLineItems::ProductsPerformance do
  let(:store) { @default_store }
  let(:report) { create(:products_performance_report, store: store) }
  let(:order) { create(:completed_order_with_totals, store: store, currency: report.currency) }

  let!(:product) { order.line_items.first.product }
  let!(:variant) { order.line_items.first.variant }

  before { order.update(completed_at: report.date_from + 1.day) }

  subject { report.line_items.first }

  describe '#vendor' do
    it 'returns vendor name from record' do
      expect(subject.vendor).to eq(variant.try(:vendor_name))
    end
  end

  describe '#brand' do
    it 'returns brand name from record' do
      expect(subject.brand).to eq(variant.try(:brand_name))
    end
  end

  describe '#category_levels' do
    let(:taxonomy) { store.taxonomies.first }
    let(:taxon) { create(:taxon, name: 'Shoes', taxonomy: taxonomy) }

    context 'when product has taxons' do
      before do
        product.taxons << taxon
        product.save!
      end

      it 'returns mapped category levels' do
        expect(subject.category_lvl0).to eq('Categories')
        expect(subject.category_lvl1).to eq('Shoes')
        expect(subject.category_lvl2).to be_nil
      end
    end

    context 'when product has no taxons' do
      it 'returns nil for all category levels' do
        expect(subject.category_lvl0).to be_nil
        expect(subject.category_lvl1).to be_nil
        expect(subject.category_lvl2).to be_nil
      end
    end
  end

  describe '#price' do
    it 'returns formatted price in report currency' do
      expect(subject.price).to eq(variant.price_in(report.currency).display_amount)
    end
  end

  describe '#weeks_online' do
    context 'with available on' do
      before do
        product.update(available_on: 2.weeks.ago)
      end

      it 'returns number of weeks since product activation' do
        expect(subject.weeks_online).to eq(2)
      end
    end

    context 'without available on' do
      before do
        product.update(available_on: nil, created_at: 3.weeks.ago)
      end

      it 'returns number of weeks since product creation' do
        expect(subject.weeks_online).to eq(3)
      end
    end
  end

  describe 'money amounts' do
    let(:line_item) { report.line_items.first }

    it 'returns formatted money amounts' do
      expect(subject.pre_tax_amount).to eq(Spree::Money.new(line_item.pre_tax_amount, currency: report.currency))
      expect(subject.tax_total).to eq(Spree::Money.new(line_item.tax_total, currency: report.currency))
      expect(subject.promo_total).to eq(Spree::Money.new(line_item.promo_total, currency: report.currency))
      expect(subject.total).to eq(Spree::Money.new(line_item.total, currency: report.currency))
    end
  end

  describe '#quantity' do
    it 'returns line item quantity' do
      expect(subject.quantity).to eq(report.line_items.first.quantity)
    end
  end

end
