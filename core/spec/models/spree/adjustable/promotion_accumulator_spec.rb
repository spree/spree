require 'spec_helper'

module Spree
  module Adjustable
    describe PromotionAccumulator do
      subject(:accumulator) { PromotionAccumulator.new(line_item) }

      let(:order)      { create(:order_with_line_items, line_items_count: 2) }
      let(:line_item)  { order.line_items.first }
      let(:line_item2) { order.line_items.last }
      let(:shipment)   { order.shipments.first }

      let(:line_item_adjustment)  { create_adjustment(line_item,  source: source,  amount: -1) }
      let(:line_item2_adjustment) { create_adjustment(line_item2, source: source,  amount: -2) }
      let(:order_adjustment)      { create_adjustment(order,      source: source2, amount: -3) }
      let(:shipment_adjustment)   { create_adjustment(shipment,   source: source3, amount: -4) }

      let(:source)  { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promo) }
      let(:source2) { Spree::Promotion::Actions::CreateAdjustment.create(promotion: promo) }
      let(:source3) { Spree::Promotion::Actions::FreeShipping.create(promotion: promo2) }

      let(:promo)  { create(:promotion) }
      let(:promo2) { create(:promotion) }

      def create_adjustment(adjustable, opts = {})
        adjustable.adjustments.create(order: order,
                                      amount: opts[:amount],
                                      label: 'Adjustment',
                                      source: opts[:source])
      end

      before { allow(Spree::Adjustable::AdjustmentsUpdater).to receive(:update) }

      describe '.add_to' do
        let(:adjustable) { double }

        before do
          allow(PromotionAccumulator).to receive(:new).and_return('New Accumulator')
          PromotionAccumulator.add_to(adjustable)
        end

        it 'adds an attribute to adjustable and assigns a new accumulator to it' do
          expect(adjustable).to respond_to(:promotion_accumulator)
          expect(adjustable.promotion_accumulator).to eq('New Accumulator')
        end
      end

      describe '#initialize' do
        before do
          line_item_adjustment
          line_item2_adjustment
          order_adjustment
        end

        it 'adds all adjustments for the order apart from those that apply to adjustable' do
          expect_any_instance_of(PromotionAccumulator).to receive(:add_adjustment).exactly(2).times
          accumulator
        end
      end

      describe '#add_adjustment' do
        context 'with multiple adjustments from multiple sources from a single promotion' do
          before do
            accumulator.add_adjustment(line_item_adjustment)
            accumulator.add_adjustment(line_item2_adjustment)
            accumulator.add_adjustment(order_adjustment)
          end

          it 'adds adjustments, sources and the promotion to respective arrays only once' do
            expect(accumulator.adjustments.count).to eq(3)
            expect(accumulator.sources.count).to eq(2)
            expect(accumulator.promotions.count).to eq(1)
          end
        end
      end

      context 'with adjustments from multiple promotions' do
        before do
          line_item_adjustment
          line_item2_adjustment
          order_adjustment
          shipment_adjustment
        end

        it do
          not_present_promo_id = promo2.id + 1
          promos_adjustments = [line_item2_adjustment, order_adjustment]
          promo2s_adjustments = [shipment_adjustment]

          expect(accumulator.promotions_adjustments(promo.id)).to eq(promos_adjustments)
          expect(accumulator.promotions_adjustments(promo2.id)).to eq(promo2s_adjustments)
          expect(accumulator.promotions_adjustments(not_present_promo_id)).to eq([])

          expect(accumulator.promo_total(promo.id)).to eq(-2 - 3)
          expect(accumulator.promo_total(promo2.id)).to eq(-4)
          expect(accumulator.promo_total(not_present_promo_id)).to eq(0)

          expect(accumulator.total_with_promotion(promo.id)).to eq(20 + 100 - 2 - 3)
          expect(accumulator.total_with_promotion(promo2.id)).to eq(20 + 100 - 4)
          expect(accumulator.total_with_promotion(not_present_promo_id)).to eq(20 + 100)

          expect(accumulator.item_total_with_promotion(promo.id)).to eq(20 - 2 - 3)
          expect(accumulator.item_total_with_promotion(promo2.id)).to eq(20)
          expect(accumulator.item_total_with_promotion(not_present_promo_id)).to eq(20)
        end
      end

      context 'with no adjustments' do
        it do
          not_present_promo_id = 1
          expect(accumulator.promotions_adjustments(not_present_promo_id)).to eq([])
          expect(accumulator.promo_total(not_present_promo_id)).to eq(0)
          expect(accumulator.total_with_promotion(not_present_promo_id)).to eq(20 + 100)
          expect(accumulator.item_total_with_promotion(not_present_promo_id)).to eq(20)
        end
      end

    end
  end
end
