require 'spec_helper'

module Spree
  module Adjustable
    describe AdjustmentsUpdater do
      let(:order) { create :order_with_line_items, line_items_count: 1 }
      let(:line_item) { order.line_items.first }
      let(:tax_rate) { create(:tax_rate, amount: 0.05) }

      describe '#update' do
        before do
          create(:adjustment, order: order, source: tax_rate, adjustable: line_item)
        end

        context 'persisted object' do
          let(:subject) { AdjustmentsUpdater.new(line_item) }

          it 'updates all linked adjusters' do
            line_item.price = 10
            line_item.tax_category = tax_rate.tax_category

            subject.update
            expect(line_item.adjustment_total).to eq(0.5)
            expect(line_item.additional_tax_total).to eq(0.5)
          end
        end

        context 'non-persisted object' do
          let(:new_line_item) { order.line_items.new }
          let(:subject) { AdjustmentsUpdater.new(new_line_item) }

          it 'does nothing' do
            expect { subject.update }.not_to change(new_line_item, :adjustment_total)
          end
        end

        context 'nil' do
          let(:subject) { AdjustmentsUpdater.new(nil) }

          it 'does not raise an error' do
            expect { subject.update }.not_to raise_error
          end
        end
      end
    end
  end
end
