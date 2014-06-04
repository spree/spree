require 'spec_helper'

module Spree
  describe ItemAdjustments do
    let(:order) { create :order_with_line_items, line_items_count: 1 }
    let(:line_item) { order.line_items.first }

    let(:subject) { ItemAdjustments.new(line_item) }

    context '#update' do
      it "updates a linked adjustment" do
        tax_rate = create(:tax_rate, :amount => 0.05)
        adjustment = create(:adjustment, :source => tax_rate, :adjustable => line_item)
        line_item.price = 10
        line_item.tax_category = tax_rate.tax_category

        subject.update
        line_item.adjustment_total.should == 0.5
        line_item.additional_tax_total.should == 0.5
      end
    end

    context "taxes and promotions" do
      let!(:tax_rate) do
        create(:tax_rate, :amount => 0.05)
      end

      let!(:promotion) do
        Spree::Promotion.create(:name => "$10 off")
      end

      let!(:promotion_action) do
        calculator = Calculator::FlatRate.new(:preferred_amount => 10)
        Promotion::Actions::CreateItemAdjustments.create calculator: calculator, promotion: promotion
      end

      before do
        line_item.price = 20
        line_item.tax_category = tax_rate.tax_category
        line_item.save
        create(:adjustment, :source => promotion_action, :adjustable => line_item, :order => order)
      end

      context "tax included in price" do
        before do
          create(:adjustment, 
            :source => tax_rate,
            :adjustable => line_item,
            :included => true,
            :order => order
          )
        end

        it "tax has no bearing on final price" do
          subject.update_adjustments
          line_item.reload
          line_item.included_tax_total.should == 0.5
          line_item.additional_tax_total.should == 0
          line_item.promo_total.should == -10
          line_item.adjustment_total.should == -10
        end
      end

      context "tax excluded from price" do
        before do
          create(:adjustment, 
            :source => tax_rate,
            :adjustable => line_item,
            :included => false
          )
        end

        it "tax applies to line item" do
          subject.update_adjustments
          line_item.reload
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

      def source
        Promotion::Actions::CreateItemAdjustments.create(
          calculator: calculator,
          promotion: Promotion.create!(name: 'test promotion')
        )
      end

      def create_adjustment(label, amount, options = {})
        create(:adjustment, :order      => order,
                            :adjustable => options[:adjustable] || line_item,
                            :source     => options[:source] || source,
                            :amount     => amount,
                            :state      => "closed",
                            :label      => label,
                            :mandatory  => false)
      end

      it "should make all but the most valuable promotion adjustment ineligible, leaving non promotion adjustments alone" do
        create_adjustment("Promotion A", -100)
        create_adjustment("Promotion B", -200)
        create_adjustment("Promotion C", -300)
        create(:adjustment, :order => order,
                            :adjustable => line_item,
                            :source => nil,
                            :amount => -500,
                            :state => "closed",
                            :label => "Some other credit")
        line_item.adjustments.each {|a| a.update_column(:eligible, true)}

        subject.choose_best_promotion_adjustment

        line_item.adjustments.promotion.eligible.count.should == 1
        line_item.adjustments.promotion.eligible.first.label.should == 'Promotion C'
      end

      context "comparing order and line item level adjustments" do
        let(:order)               { create :order_with_line_items, line_items_count: 2 }
        let(:line_item_1)         { order.line_items.first }
        let(:line_item_2)         { order.line_items.last }
        let(:order_promotion)     { Promotion.create! name: "Order promotion" }
        let(:line_item_promotion) { Promotion.create! name: "Line item promotion" }
        let(:order_source)        { Promotion::Actions::CreateAdjustment.create! calculator: calculator, promotion: order_promotion }
        let(:line_item_source)    { Promotion::Actions::CreateAdjustment.create! calculator: calculator, promotion: line_item_promotion }
        let!(:order_adjustment)   { create_adjustment("Order Promotion", order_discount, adjustable: order, source: order_source) }
        let!(:item_adjustment_1)  { create_adjustment("Item Promotion 1", item_1_discount, adjustable: line_item_1, source: line_item_source) }
        let!(:item_adjustment_2)  { create_adjustment("Item Promotion 2", item_2_discount, adjustable: line_item_2, source: line_item_source) }
        before                    { Spree::Adjustment.update_all(eligible: true) }

        context "the order level adjustment is greater than all of the line item adjustments for the same promotion put together" do
          let(:order_discount)  { -100 }
          let(:item_1_discount) { -30 }
          let(:item_2_discount) { -40 }

          it "chooses the order level adjustment" do
            subject.choose_best_promotion_adjustment
            expect(order_adjustment.reload).to be_eligible
            expect(item_adjustment_1.reload).not_to be_eligible
            expect(item_adjustment_2.reload).not_to be_eligible
          end
        end

        context "the order level adjustment is less than all of the line item adjustments for the same promotion put together" do
          let(:order_discount)  { -50 }
          let(:item_1_discount) { -30 }
          let(:item_2_discount) { -40 }

          it "chooses all the line item level adjustments" do
            subject.choose_best_promotion_adjustment
            expect(order_adjustment.reload).not_to be_eligible
            expect(item_adjustment_1.reload).to be_eligible
            expect(item_adjustment_2.reload).to be_eligible
          end
        end

        context "the order level adjustment is the same as all of the line item adjustments for the same promotion put together" do
          let(:order_discount)  { -50 }
          let(:item_1_discount) { -10 }
          let(:item_2_discount) { -40 }

          it "chooses just the order level adjustment" do
            subject.choose_best_promotion_adjustment
            expect(order_adjustment.reload).to be_eligible
            expect(item_adjustment_1.reload).not_to be_eligible
            expect(item_adjustment_2.reload).not_to be_eligible
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
          subject.choose_best_promotion_adjustment
          line_item.adjustments.promotion.eligible.first.label.should == 'Promotion A'
        end
      end

      it "should only leave one adjustment even if 2 have the same amount" do
        create_adjustment("Promotion A", -100)
        create_adjustment("Promotion B", -200)
        create_adjustment("Promotion C", -200)

        subject.choose_best_promotion_adjustment

        line_item.adjustments.promotion.eligible.count.should == 1
        line_item.adjustments.promotion.eligible.first.amount.to_i.should == -200
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
        subject.update_adjustments
        expect(subject.before_promo_adjustments_called).to be_true
        expect(subject.after_promo_adjustments_called).to be_true
        expect(subject.before_tax_adjustments_called).to be_true
        expect(subject.after_tax_adjustments_called).to be_true
      end
    end
  end
end
