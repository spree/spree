require 'spec_helper'

module Spree
  module Adjustable
    describe PromotionAccumulator do
      subject(:accumulator) { PromotionAccumulator.new(line_item) }

      let(:order)      { create(:order_with_line_items, line_items_count: 2) }
      let(:line_item)  { order.line_items.first }
      let(:line_item2) { order.line_items.last }
      let(:shipment)   { order.shipments.first }

      let(:line_item_adjustment)     { create_adjustment(line_item,  source: item_source,     amount: -1) }
      let(:line_item2_adjustment)    { create_adjustment(line_item2, source: item_source,     amount: -2) }
      let(:order_adjustment)         { create_adjustment(order,      source: order_source,    amount: -3) }
      let(:shipment_adjustment)      { create_adjustment(shipment,   source: shipping_source, amount: -4) }

      let(:item_source)     { Spree::Promotion::Actions::CreateItemAdjustments.create(promotion: promotion) }
      let(:order_source)    { Spree::Promotion::Actions::CreateAdjustment.create(promotion: promotion) }
      let(:shipping_source) { Spree::Promotion::Actions::FreeShipping.create(promotion: promotion2) }

      let(:promotion)  { create(:promotion) }
      let(:promotion2) { create(:promotion) }

      def create_adjustment(adjustable, opts={})
        adjustable.adjustments.create({
          order: order, 
          amount: opts[:amount], 
          label: 'Adjustment', 
          source: opts[:source]
        })
      end

      before { allow(Spree::ItemAdjustments).to receive(:update) }

      describe '.add_to' do 
        let(:adjustable) { double() }

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
          expect(accumulator.promotions_adjustments(1)).to eq([line_item2_adjustment, order_adjustment])
          expect(accumulator.promotions_adjustments(2)).to eq([shipment_adjustment])
          expect(accumulator.promotions_adjustments(3)).to eq([])
          expect(accumulator.promo_total(1)).to eq(-2 - 3)
          expect(accumulator.promo_total(2)).to eq(-4    )
          expect(accumulator.promo_total(3)).to eq( 0    )
          expect(accumulator.total_with_promotion(1)).to eq(20 + 100 - 2 - 3)
          expect(accumulator.total_with_promotion(2)).to eq(20 + 100 - 4    )
          expect(accumulator.total_with_promotion(3)).to eq(20 + 100        )
          expect(accumulator.item_total_with_promotion(1)).to eq(20 - 2 - 3)
          expect(accumulator.item_total_with_promotion(2)).to eq(20        )
          expect(accumulator.item_total_with_promotion(3)).to eq(20        )
        end
      end

      context 'with no adjustments' do 
        it do 
          expect(accumulator.promotions_adjustments(1)).to eq([])
          expect(accumulator.promo_total(1)).to eq(0)
          expect(accumulator.total_with_promotion(1)).to eq(20 + 100)
          expect(accumulator.item_total_with_promotion(1)).to eq(20)
        end
      end

    end
  end
end