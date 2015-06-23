require 'spec_helper'

module Spree
  module Adjustable
    describe AdjustmentsUpdater do
      let(:order) { create :order_with_line_items, line_items_count: 1 }
      let(:line_item) { order.line_items.first }

      let(:subject) { AdjustmentsUpdater.new(line_item) }
      let(:order_subject) { AdjustmentsUpdater.new(order) }

      describe '#update' do
        it "updates all linked adjusters" do
          tax_rate = create(:tax_rate, amount: 0.05)
          create(:adjustment, order: order, source: tax_rate, adjustable: line_item)
          line_item.price = 10
          line_item.tax_category = tax_rate.tax_category

          subject.update
          expect(line_item.adjustment_total).to eq(0.5)
          expect(line_item.additional_tax_total).to eq(0.5)
        end
      end
    end
  end
end
