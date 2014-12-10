require 'spec_helper'

module Spree
  module Adjustable
    describe PromotionSelector do
      subject(:selector) { PromotionSelector.new(adjustable) }

      let(:adjustable)  { line_item2 }
      let(:order)       { create(:order_with_line_items, line_items_count: 2) }
      let(:line_item)   { order.line_items.first }
      let(:line_item2)  { order.line_items.last }
      let(:accumulator) { adjustable.promotion_accumulator }

      let(:adjustment)  { create_adjustment(line_item,  source: source,  amount: -1) }
      let(:adjustment2) { create_adjustment(line_item,  source: source2, amount: -2) }
      let(:adjustment3) { create_adjustment(line_item2, source: source3, amount: -3) }
      let(:adjustment4) { create_adjustment(line_item2, source: source4, amount: -5) }

      let(:source)  { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promo2) }
      let(:source2) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promo)  }
      let(:source3) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promo)  }
      let(:source4) { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promo2) }

      let(:promo)  { create(:promotion) }
      let(:promo2) { create(:promotion) }

      def create_adjustment(adjustable, opts = {})
        adjustable.adjustments.create(order: order,
                                      amount: opts[:amount],
                                      label: 'Adjustment',
                                      source: opts[:source])
      end

      before { allow(AdjustmentsUpdater).to receive(:update) }

      describe '#select!' do

        context 'with no adjustments' do
          before { PromotionAccumulator.add_to(adjustable) }
          it 'returns 0 for the promo total of adjustable' do
            expect(selector.select!).to eq(0)
          end
        end

        context 'with multiple adjustments from multiple promotions' do
          before do
            adjustment
            adjustment2
            line_item.update_column(:promo_total, -2)

            PromotionAccumulator.add_to(adjustable)
            accumulator.add_adjustment(adjustment3)
            accumulator.add_adjustment(adjustment4)
          end

          it 'returns promo total of adjustable' do
            expect(selector.select!).to eq(-5)
          end

          it 'set only the best promotions adjustments to eligible' do
            selector.select!
            expect(adjustment.reload.eligible).to be(true)
            expect(adjustment2.reload.eligible).to be(false)
            expect(adjustment3.reload.eligible).to be(false)
            expect(adjustment4.reload.eligible).to be(true)
          end

          it 'updates other adjustables promo totals' do
            selector.select!
            expect(line_item.reload.promo_total).to eq(-1)
          end
        end

      end

    end
  end
end

