require 'spec_helper'

module Spree
  module Adjustable
    describe AdjustmentsUpdater do
      let(:order) { create :order_with_line_items, line_items_count: 1 }
      let(:line_item) { order.line_items.first }

      let(:subject) { AdjustmentsUpdater.new(line_item) }
      let(:order_subject) { AdjustmentsUpdater.new(order) }

      context '#update' do
        it "updates a linked adjustment" do
          tax_rate = create(:tax_rate, amount: 0.05)
          create(:adjustment, order: order, source: tax_rate, adjustable: line_item)
          line_item.price = 10
          line_item.tax_category = tax_rate.tax_category

          subject.update
          expect(line_item.adjustment_total).to eq(0.5)
          expect(line_item.additional_tax_total).to eq(0.5)
        end
      end

      context "taxes and promotions" do
        let!(:tax_rate) do
          create(:tax_rate, amount: 0.05)
        end

        let!(:promotion) do
          Spree::Promotion.create(name: "$10 off")
        end

        let!(:promotion_action) do
          calculator = Calculator::FlatRate.new(preferred_amount: 10)
          Promotion::Actions::CreateItemAdjustments.create(calculator: calculator,
                                                           promotion: promotion)
        end

        before do
          line_item.price = 20
          line_item.tax_category = tax_rate.tax_category
          line_item.save
          create(:adjustment, order: order, source: promotion_action, adjustable: line_item)
        end

        context "tax included in price" do
          before do
            create(:adjustment, source: tax_rate,
                                adjustable: line_item,
                                order: order,
                                included: true)
          end

          it "tax has no bearing on final price" do
            subject.update
            line_item.reload
            expect(line_item.included_tax_total).to eq(0.5)
            expect(line_item.additional_tax_total).to eq(0)
            expect(line_item.promo_total).to eq(-10)
            expect(line_item.adjustment_total).to eq(-10)
          end

          it "tax linked to order" do
            order_subject.update
            order.reload
            expect(order.included_tax_total).to eq(0.5)
            expect(order.additional_tax_total).to eq(00)
          end
        end

        context "tax excluded from price" do
          before do
            create(:adjustment, source: tax_rate,
                                adjustable: line_item,
                                order: order,
                                included: false)
          end

          it "tax applies to line item" do
            subject.update
            line_item.reload
            # Taxable amount is: $20 (base) - $10 (promotion) = $10
            # Tax rate is 5% (of $10).
            expect(line_item.included_tax_total).to eq(0)
            expect(line_item.additional_tax_total).to eq(0.5)
            expect(line_item.promo_total).to eq(-10)
            expect(line_item.adjustment_total).to eq(-9.5)
          end

          it "tax linked to order" do
            order_subject.update
            order.reload
            expect(order.included_tax_total).to eq(0)
            expect(order.additional_tax_total).to eq(0.5)
          end
        end
      end

      context "best promotion is always applied" do
        let(:calculator) { Calculator::FlatRate.new(preferred_amount: 10) }

        let(:source) { Promotion::Actions::CreateItemAdjustments.create calculator: calculator }

        def create_adjustment(label, amount)
          create(:adjustment, order:      order,
                              adjustable: line_item,
                              source:     source,
                              amount:     amount,
                              state:      "closed",
                              label:      label,
                              mandatory:  false)
        end

        it "should make all but the most valuable promotion adjustment ineligible, " +
           "leaving non promotion adjustments alone" do
          create_adjustment("Promotion A", -100)
          create_adjustment("Promotion B", -200)
          create_adjustment("Promotion C", -300)
          create(:adjustment, order:  order,
                              adjustable:  line_item,
                              source:  nil,
                              amount:  -500,
                              state:  "closed",
                              label:  "Some other credit")
          line_item.adjustments.each { |a| a.update_column(:eligible, true) }

          subject.update

          expect(line_item.adjustments.promotion.eligible.count).to eq(1)
          expect(line_item.adjustments.promotion.eligible.first.label).to eq('Promotion C')
        end

        it "should choose the most recent promotion adjustment when amounts are equal" do
          # Using Timecop is a regression test
          Timecop.freeze do
            create_adjustment("Promotion A", -200)
            create_adjustment("Promotion B", -200)
          end
          line_item.adjustments.each { |a| a.update_column(:eligible, true) }

          subject.update

          expect(line_item.adjustments.promotion.eligible.count).to eq(1)
          expect(line_item.adjustments.promotion.eligible.first.label).to eq('Promotion B')
        end

        context "when previously ineligible promotions become available" do
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
            it "should pick the best order-level promo according to current eligibility" do
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

              order.contents.add create(:variant, price: 10), 1
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
            it "should pick the best line-item-level promo according to current eligibility" do
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

              order.contents.add create(:variant, price: 10), 1
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

        context "multiple adjustments and the best one is not eligible" do
          let!(:promo_a) { create_adjustment("Promotion A", -100) }
          let!(:promo_c) { create_adjustment("Promotion C", -300) }

          before do
            promo_a.update_column(:eligible, true)
            promo_c.update_column(:eligible, false)
          end

          # regression for #3274
          it "still makes the previous best eligible adjustment valid" do
            subject.update
            expect(line_item.adjustments.promotion.eligible.first.label).to eq('Promotion A')
          end
        end

        it "should only leave one adjustment even if 2 have the same amount" do
          create_adjustment("Promotion A", -100)
          create_adjustment("Promotion B", -200)
          create_adjustment("Promotion C", -200)

          subject.update

          expect(line_item.adjustments.promotion.eligible.count).to eq(1)
          expect(line_item.adjustments.promotion.eligible.first.amount.to_i).to eq(-200)
        end
      end

    end
  end
end
