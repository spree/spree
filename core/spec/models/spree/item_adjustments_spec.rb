require 'spec_helper'

module Spree
  describe ItemAdjustments do
    let(:variant) do
      Spree::Variant.new(id: 1)
    end

    let(:line_item) do 
      Spree::LineItem.new(variant: variant, price: 10, quantity: 1)
    end

    let(:order) do
      Spree::Order.new.tap do |order|
        order.line_items << line_item
        order.item_total = line_item.amount
      end
    end

    let(:tax_rate) do
      Spree::TaxRate.new(amount: 0.05, calculator: Spree::Calculator::DefaultTax.new)
    end

    let(:subject) { ItemAdjustments.new(line_item) }

    context '#update' do
      it "updates a linked adjustment" do
        line_item.adjustments.build(source: tax_rate, included: false, adjustable: line_item)
        line_item.tax_category = tax_rate.tax_category

        subject.calculate_adjustments
        line_item.adjustment_total.should == 0.5
        line_item.additional_tax_total.should == 0.5
      end
    end

    context "taxes and promotions" do
      let!(:promotion) do
        Spree::Promotion.new(:name => "$10 off")
      end

      let!(:promotion_action) do
        calculator = Calculator::FlatRate.new(:preferred_amount => 10)
        Promotion::Actions::CreateItemAdjustments.new calculator: calculator, promotion: promotion
      end

      before do
        line_item.price = 20
        line_item.tax_category = tax_rate.tax_category
        line_item.adjustments.build(source: promotion_action, adjustable: line_item)
      end

      context "tax included in price" do
        before do
          line_item.adjustments.build(source: tax_rate, included: true, adjustable: line_item)
        end

        it "tax has no bearing on final price" do
          subject.calculate_adjustments
          line_item.included_tax_total.should == 0.5
          line_item.additional_tax_total.should == 0
          line_item.promo_total.should == -10
          line_item.adjustment_total.should == -10
        end
      end

      context "tax excluded from price" do
        before do
          line_item.adjustments.build(source: tax_rate, included: false, adjustable: line_item)
        end

        it "tax applies to line item" do
          subject.calculate_adjustments
          # Taxable amount is: $20 (base) - $10 (promotion) = $10
          # Tax rate is 5% (of $10).
          line_item.included_tax_total.should == 0
          line_item.additional_tax_total.should == 0.5
          line_item.promo_total.should == -10
          line_item.adjustment_total.should == -9.5
        end
      end
    end

    context "best promotion is always applied" do
      let(:calculator) { Calculator::FlatRate.new(:preferred_amount => 10) }

      let(:source) { Promotion::Actions::CreateItemAdjustments.new calculator: calculator }

      def create_adjustment(label, amount)
        line_item.adjustments.build(
          order: order,
          adjustable: line_item,
          source: source,
          amount: amount,
          state: "closed",
          label: label,
          mandatory: false
        )
      end

      it "should make all but the most valuable promotion adjustment ineligible, leaving non promotion adjustments alone" do
        create_adjustment("Promotion A", -100)
        create_adjustment("Promotion B", -200)
        create_adjustment("Promotion C", -300)

        line_item.adjustments.build(
          order: order,
          adjustable: line_item,
          source: nil,
          amount: -500,
          state: "closed",
          label: "Some other credit",
          mandatory: false
        )

        line_item.adjustments.each { |a| a.eligible = true }

        subject.choose_best_promotion_adjustment

        eligible_promotions = line_item.adjustments.select(&:promotion?).select(&:eligible?)
        eligible_promotions.count.should == 1
        eligible_promotions.first.label.should == 'Promotion C'
      end

      context "when previously ineligible promotions become available" do
        let(:order_promo1) do
          promotion = Spree::Promotion.new(name: "Promotion #1")
          order_adjustment_action = Spree::Promotion::Actions::CreateAdjustment.new(promotion: promotion)
          order_adjustment_action.calculator = Spree::Calculator::FlatRate.new
          order_adjustment_action.calculator.preferred_amount = 5
          promotion.actions << order_adjustment_action

          item_total_rule = Spree::Promotion::Rules::ItemTotal.new(preferred_amount: 10, preferred_operator: 'gte')
          promotion.rules << item_total_rule
          promotion
        end

        let(:order_promo2) do
          promotion = Spree::Promotion.new(name: "Promotion #2")
          order_adjustment_action = Spree::Promotion::Actions::CreateAdjustment.new(promotion: promotion)
          order_adjustment_action.calculator = Spree::Calculator::FlatRate.new
          order_adjustment_action.calculator.preferred_amount = 10
          promotion.actions << order_adjustment_action

          item_total_rule = Spree::Promotion::Rules::ItemTotal.new(preferred_amount: 20, preferred_operator: 'gte')
          promotion.rules << item_total_rule
          promotion
        end

        let(:order_promos) { [ order_promo1, order_promo2 ] }

        let(:line_item_promo1) do
          promotion = Spree::Promotion.new(name: "Promotion #1")
          order_adjustment_action = Spree::Promotion::Actions::CreateItemAdjustments.new(promotion: promotion)
          order_adjustment_action.calculator = Spree::Calculator::FlatRate.new
          order_adjustment_action.calculator.preferred_amount = 2.5
          promotion.actions << order_adjustment_action

          item_total_rule = Spree::Promotion::Rules::ItemTotal.new(preferred_amount: 10, preferred_operator: 'gte')
          promotion.rules << item_total_rule
          promotion
        end

        let(:line_item_promo2) do
          promotion = Spree::Promotion.new(name: "Promotion #2")
          order_adjustment_action = Spree::Promotion::Actions::CreateItemAdjustments.new(promotion: promotion)
          order_adjustment_action.calculator = Spree::Calculator::FlatRate.new
          order_adjustment_action.calculator.preferred_amount = 5
          promotion.actions << order_adjustment_action

          item_total_rule = Spree::Promotion::Rules::ItemTotal.new(preferred_amount: 20, preferred_operator: 'gte')
          promotion.rules << item_total_rule
          promotion
        end
        let(:line_item_promos) { [ line_item_promo1, line_item_promo2 ] }

        # Apply promotions in different sequences. Results should be the same.
        promo_sequences = [
          [ 0, 1 ],
          [ 1, 0 ]
        ]

        promo_sequences.each do |promo_sequence|
          it "should pick the best order-level promo according to current eligibility" do
            # apply both promos to the order, even though only promo1 is eligible
            order_promos[promo_sequence[0]].activate order: order
            order_promos[promo_sequence[1]].activate order: order

            order.all_adjustments.count.should eq(2), "Expected two adjustments (using sequence #{promo_sequence})"
            eligible_adjustments = order.all_adjustments.select(&:eligible?)
            eligible_adjustments.length.should eq(1), "Expected one eligible adjustment (using sequence #{promo_sequence})"
            eligible_adjustments.first.source.promotion.should eq(order_promo1), "Expected promo1 to be used (using sequence #{promo_sequence})"

            new_variant = Spree::Variant.new(price: 10)
            order.contents.add new_variant, 1

            order.adjustments.length.should eq(2), "Expected two adjustments (using sequence #{promo_sequence})"
            eligible_adjustments = order.adjustments.select(&:eligible?)
            eligible_adjustments.length.should eq(1), "Expected one eligible adjustment (using sequence #{promo_sequence})"
            eligible_adjustments.first.source.promotion.should eq(order_promo2), "Expected promo1 to be used (using sequence #{promo_sequence})"
          end
        end

        # promo_sequences.each do |promo_sequence|
          it "should pick the best line-item-level promo according to current eligibility" do
            # apply both promos to the order, even though only promo1 is eligible
            line_item_promos[0].activate order: order
            line_item_promos[1].activate order: order

            order.all_adjustments.count.should eq(2)#, "Expected two adjustments (using sequence #{promo_sequence})"
            eligible_adjustments = order.all_adjustments.select(&:eligible?)
            eligible_adjustments.length.should eq(1)#, "Expected one eligible adjustment (using sequence #{promo_sequence})"
            eligible_adjustments.first.source.promotion.should eq(line_item_promo1)#, "Expected promo1 to be used (using sequence #{promo_sequence})"

            new_variant = Spree::Variant.new(id: 2, price: 10)
            order.contents.add new_variant, 1

            # Calling activate here, even though it would normally be handled by OrderContents#add
            # It's not handled because the Promotion we're working with here is not persisted
            # Stubbing would be too messy, and since all PromotionHandler::Cart#activate does is the following...
            # It's no big deal.
            line_item_promos[0].activate order: order
            line_item_promos[1].activate order: order

            order.all_adjustments.count.should eq(4)#, "Expected four adjustments (using sequence #{promo_sequence})"
            eligible_adjustments = order.all_adjustments.select(&:eligible?)
            eligible_adjustments.count.should eq(2)#, "Expected two eligible adjustments (using sequence #{promo_sequence})"
            eligible_adjustments.each do |adjustment|
              adjustment.source.promotion.should eq(line_item_promo2)#, "Expected line_item_promo2 to be used (using sequence #{promo_sequence})"
            end
          # end
        end
      end

      context "multiple adjustments and the best one is not eligible" do
        let!(:promo_a) { create_adjustment("Promotion A", -100) }
        let!(:promo_c) { create_adjustment("Promotion C", -300) }

        before do
          promo_a.eligible = true
          promo_c.eligible = false
        end

        # regression for #3274
        it "still makes the previous best eligible adjustment valid" do
          subject.choose_best_promotion_adjustment
          line_item.adjustments.select(&:promotion?).select(&:eligible?).first.label.should == 'Promotion A'
        end
      end

      it "should only leave one adjustment even if 2 have the same amount" do
        create_adjustment("Promotion A", -100)
        create_adjustment("Promotion B", -200)
        create_adjustment("Promotion C", -200)

        subject.choose_best_promotion_adjustment

        eligible_promotion_adjustments = line_item.adjustments.select(&:promotion?).select(&:eligible?)
        eligible_promotion_adjustments.count.should == 1
        eligible_promotion_adjustments.first.amount.to_i.should == -200
      end
    end

    # For #4483
    context "callbacks" do
      class SuperItemAdjustments < Spree::ItemAdjustments
        attr_accessor :before_promo_adjustments_called,
                      :after_promo_adjustments_called,
                      :before_tax_adjustments_called,
                      :after_tax_adjustments_called

        set_callback :promo_adjustments, :before do |object|
          @before_promo_adjustments_called = true
        end

        set_callback :promo_adjustments, :after do |object|
          @after_promo_adjustments_called = true
        end

        set_callback :tax_adjustments, :before do |object|
          @before_tax_adjustments_called = true
        end

        set_callback :promo_adjustments, :after do |object|
          @after_tax_adjustments_called = true
        end
      end
      let(:subject) { SuperItemAdjustments.new(line_item) }

      it "calls all the callbacks" do
        subject.calculate_adjustments
        expect(subject.before_promo_adjustments_called).to be_true
        expect(subject.after_promo_adjustments_called).to be_true
        expect(subject.before_tax_adjustments_called).to be_true
        expect(subject.after_tax_adjustments_called).to be_true
      end
    end
  end
end
