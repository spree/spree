require 'spec_helper'

module Spree
  module Adjustable
    describe AdjustmentsUpdater do
      let(:order) { create :order_with_line_items, line_items_count: 1 }
      let(:line_item) { order.line_items.first }
      let(:tax_rate) { create(:tax_rate, amount: 0.05) }

      let(:promotion) { create(:promotion, :with_line_item_adjustment, adjustment_rate: 2) }
      let(:promotion_action) { promotion.actions.first }

      describe '#update' do
        let(:promo_total) { -2 }
        let(:tax_total) { 0.4 }

        let(:adjustments) do
          [
            create(:adjustment, order: order, source: promotion_action, adjustable: line_item),
            create(:adjustment, order: order, source: tax_rate, adjustable: line_item)
          ]
        end

        context 'persisted object' do
          subject { AdjustmentsUpdater.new(line_item) }

          it 'updates all linked adjusters' do
            adjustments

            line_item.price = 10
            line_item.tax_category = tax_rate.tax_category
            line_item.adjustment_total = 0
            line_item.additional_tax_total = 0
            old_updated_at = line_item.updated_at

            subject.update
            expect(line_item.promo_total).to eq(promo_total)
            expect(line_item.additional_tax_total).to eq(tax_total)
            expect(line_item.adjustment_total).to eq(tax_total + promo_total)
            expect(line_item.updated_at).not_to eq(old_updated_at)

            old_updated_at = line_item.updated_at

            subject.update
            # skipping the update because the totals have not changed
            line_item.reload
            expect(line_item.promo_total).to eq(promo_total)
            expect(line_item.additional_tax_total).to eq(tax_total)
            expect(line_item.adjustment_total).to eq(tax_total + promo_total)
            expect(line_item.updated_at).to eq(old_updated_at)
          end

          context 'when there is no tax adjuster' do
            before do
              allow(Rails.application.config.spree).to receive(:adjusters).and_return([Spree::Adjustable::Adjuster::Promotion])
            end

            it 'updates all linked adjusters without tax' do
              adjustments

              line_item.price = 10
              line_item.tax_category = tax_rate.tax_category
              line_item.adjustment_total = 0
              line_item.additional_tax_total = 0
              old_updated_at = line_item.updated_at

              subject.update
              expect(line_item.promo_total).to eq(promo_total)
              expect(line_item.additional_tax_total).to eq(0)
              expect(line_item.adjustment_total).to eq(promo_total)
              expect(line_item.updated_at).not_to eq(old_updated_at)

              old_updated_at = line_item.updated_at

              subject.update
              # skipping the update because the totals have not changed
              line_item.reload
              expect(line_item.promo_total).to eq(promo_total)
              expect(line_item.additional_tax_total).to eq(0)
              expect(line_item.adjustment_total).to eq(promo_total)
              expect(line_item.updated_at).to eq(old_updated_at)
            end
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
