require 'spec_helper'

describe Spree::Adjustable::Adjuster::Promotion, type: :model do
  let(:order) { create :order_with_line_items, line_items_count: 1 }
  let(:line_item) { order.line_items.first }
  let(:subject) { Spree::Adjustable::AdjustmentsUpdater.new(line_item) }
  let(:order_subject) { Spree::Adjustable::AdjustmentsUpdater.new(order) }

  context 'best promotion is always applied' do
    let(:calculator) { Spree::Calculator::FlatRate.new(preferred_amount: 10) }
    let(:source) { Spree::Promotion::Actions::CreateItemAdjustments.create calculator: calculator }

    def create_adjustment(label, amount)
      create(:adjustment,
             order: order,
             adjustable: line_item,
             source: source,
             amount: amount,
             state: 'closed',
             label: label,
             mandatory: false)
    end

    describe 'competing promos' do
      before { Spree::Adjustment.competing_promos_source_types = ['Spree::PromotionAction', 'Custom'] }

      it 'do not update promo_total' do
        create(:adjustment,
               order: order,
               adjustable: line_item,
               source_type: 'Custom',
               source_id: nil,
               amount: -3.50,
               label: 'Other',
               mandatory: false)
        create_adjustment('Promotion A', -2.50)

        subject.update
        expect(line_item.promo_total).to eq(0.0)
      end
    end

    it 'uses only the most valuable promotion' do
      create_adjustment('Promotion A', -100)
      create_adjustment('Promotion B', -200)
      create_adjustment('Promotion C', -300)
      create(:adjustment,
             order: order,
             adjustable: line_item,
             source: nil,
             amount: -500,
             state: 'closed',
             label: 'Some other credit')
      line_item.adjustments.each { |a| a.update_column(:eligible, true) }

      subject.update

      expect(line_item.adjustments.promotion.eligible.count).to eq(1)
      expect(line_item.adjustments.promotion.eligible.first.label).to eq('Promotion C')
    end

    it 'chooses the most recent promotion adjustment when amounts are equal' do
      # Using Timecop is a regression test
      Timecop.freeze do
        create_adjustment('Promotion A', -200)
        create_adjustment('Promotion B', -200)
      end
      line_item.adjustments.each { |a| a.update_column(:eligible, true) }

      subject.update

      expect(line_item.adjustments.promotion.eligible.count).to eq(1)
      expect(line_item.adjustments.promotion.eligible.first.label).to eq('Promotion B')
    end

    context 'when previously ineligible promotions become available' do
      let(:order_promo1) do
        create(:promotion,
               :with_order_adjustment,
               :with_item_total_rule,
               weighted_order_adjustment_amount: 5,
               item_total_threshold_amount: 10)
      end

      let(:order_promo2) do
        create(:promotion,
               :with_order_adjustment,
               :with_item_total_rule,
               weighted_order_adjustment_amount: 10,
               item_total_threshold_amount: 20)
      end

      let(:order_promos) { [order_promo1, order_promo2] }

      let(:line_item_promo1) do
        create(:promotion,
               :with_line_item_adjustment,
               :with_item_total_rule,
               adjustment_rate: 2.5,
               item_total_threshold_amount: 10)
      end

      let(:line_item_promo2) do
        create(:promotion,
               :with_line_item_adjustment,
               :with_item_total_rule,
               adjustment_rate: 5,
               item_total_threshold_amount: 20)
      end

      let(:line_item_promos) { [line_item_promo1, line_item_promo2] }
      let(:order) { create(:order_with_line_items, line_items_count: 1) }

      # Apply promotions in different sequences. Results should be the same.
      promo_sequences = [[0, 1], [1, 0]]

      promo_sequences.each do |promo_sequence|
        it 'picks the best order-level promo according to current eligibility' do
          # apply both promos to the order, even though only promo1 is eligible
          order_promos[promo_sequence[0]].activate order: order
          order_promos[promo_sequence[1]].activate order: order

          order.reload
          msg = "Expected two adjustments (using sequence #{promo_sequence})"
          expect(order.all_adjustments.count).to eq(2), msg

          msg = "Expected one elegible adjustment (using sequence #{promo_sequence})"
          expect(order.all_adjustments.eligible.count).to eq(1), msg

          msg = "Expected promo1 to be used (using sequence #{promo_sequence})"
          expect(order.all_adjustments.eligible.first.source.promotion).to eq(order_promo1), msg

          Spree::Cart::AddItem.call(order: order, variant: create(:variant, price: 10))
          order.save

          order.reload
          msg = "Expected two adjustments (using sequence #{promo_sequence})"
          expect(order.all_adjustments.count).to eq(2), msg

          msg = "Expected one elegible adjustment (using sequence #{promo_sequence})"
          expect(order.all_adjustments.eligible.count).to eq(1), msg

          msg = "Expected promo2 to be used (using sequence #{promo_sequence})"
          expect(order.all_adjustments.eligible.first.source.promotion).to eq(order_promo2), msg
        end
      end

      promo_sequences.each do |promo_sequence|
        it 'picks the best line-item-level promo according to current eligibility' do
          # apply both promos to the order, even though only promo1 is eligible
          line_item_promos[promo_sequence[0]].activate order: order
          line_item_promos[promo_sequence[1]].activate order: order

          order.reload
          msg = "Expected one adjustment (using sequence #{promo_sequence})"
          expect(order.all_adjustments.count).to eq(1), msg

          msg = "Expected one elegible adjustment (using sequence #{promo_sequence})"
          expect(order.all_adjustments.eligible.count).to eq(1), msg

          # line_item_promo1 is the only one that has thus far met the order total threshold,
          # it is the only promo which should be applied.
          msg = "Expected line_item_promo1 to be used (using sequence #{promo_sequence})"
          expect(order.all_adjustments.first.source.promotion).to eq(line_item_promo1), msg

          Spree::Cart::AddItem.call(order: order, variant: create(:variant, price: 10))
          order.save

          order.reload
          msg = "Expected four adjustments (using sequence #{promo_sequence})"
          expect(order.all_adjustments.count).to eq(4), msg

          msg = "Expected two elegible adjustments (using sequence #{promo_sequence})"
          expect(order.all_adjustments.eligible.count).to eq(2), msg

          order.all_adjustments.eligible.each do |adjustment|
            msg = "Expected line_item_promo2 to be used (using sequence #{promo_sequence})"
            expect(adjustment.source.promotion).to eq(line_item_promo2), msg
          end
        end
      end
    end

    context 'multiple adjustments and the best one is not eligible' do
      let!(:promo_a) { create_adjustment('Promotion A', -100) }
      let!(:promo_c) { create_adjustment('Promotion C', -300) }

      before do
        promo_a.update_column(:eligible, true)
        promo_c.update_column(:eligible, false)
      end

      # regression for #3274
      it 'still makes the previous best eligible adjustment valid' do
        subject.update
        expect(line_item.adjustments.promotion.eligible.first.label).to eq('Promotion A')
      end
    end

    it 'only leaves one adjustment even if 2 have the same amount' do
      create_adjustment('Promotion A', -100)
      create_adjustment('Promotion B', -200)
      create_adjustment('Promotion C', -200)

      subject.update

      expect(line_item.adjustments.promotion.eligible.count).to eq(1)
      expect(line_item.adjustments.promotion.eligible.first.amount.to_i).to eq(-200)
    end
  end
end
