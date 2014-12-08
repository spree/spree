require 'spec_helper'

module Spree
  describe ItemAdjustments do
    let(:order) { create :order_with_line_items, line_items_count: 1 }
    let(:line_item) { order.line_items.first }

    context '#update' do
      it "updates a linked adjustment" do
        tax_rate = create(:tax_rate, :amount => 0.05)
        adjustment = create(:adjustment, order: order, source: tax_rate, adjustable: line_item)
        line_item.price = 10
        line_item.tax_category = tax_rate.tax_category

        ItemAdjustments.update(line_item)
        expect(line_item.adjustment_total).to eq(0.5)
        expect(line_item.additional_tax_total).to eq(0.5)
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
        create(:adjustment, order: order, source: promotion_action, adjustable: line_item)
      end

      context "tax included in price" do
        before do
          create(:adjustment,
            :source => tax_rate,
            :adjustable => line_item,
            :order => order,
            :included => true
          )
        end

        it "tax has no bearing on final price" do
          ItemAdjustments.update(line_item)
          line_item.reload
          expect(line_item.included_tax_total).to eq(0.5)
          expect(line_item.additional_tax_total).to eq(0)
          expect(line_item.promo_total).to eq(-10)
          expect(line_item.adjustment_total).to eq(-10)
        end

        it "tax linked to order" do
          ItemAdjustments.update(order)
          order.reload
          expect(order.included_tax_total).to eq(0.5)
          expect(order.additional_tax_total).to eq(00)
        end
      end

      context "tax excluded from price" do
        before do
          create(:adjustment,
            :source => tax_rate,
            :adjustable => line_item,
            :order => order,
            :included => false
          )
        end

        it "tax applies to line item" do
          ItemAdjustments.update(line_item)
          line_item.reload
          # Taxable amount is: $20 (base) - $10 (promotion) = $10
          # Tax rate is 5% (of $10).
          expect(line_item.included_tax_total).to eq(0)
          expect(line_item.additional_tax_total).to eq(0.5)
          expect(line_item.promo_total).to eq(-10)
          expect(line_item.adjustment_total).to eq(-9.5)
        end

        it "tax linked to order" do
          ItemAdjustments.update(order)
          order.reload
          expect(order.included_tax_total).to eq(0)
          expect(order.additional_tax_total).to eq(0.5)
        end
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

        set_callback :tax_adjustments, :after do |object|
          @after_tax_adjustments_called = true
        end
      end
      let(:subject) { SuperItemAdjustments.new(line_item) }

      it "calls all the callbacks" do
        subject.update
        expect(subject.before_promo_adjustments_called).to be true
        expect(subject.after_promo_adjustments_called).to be true
        expect(subject.before_tax_adjustments_called).to be true
        expect(subject.after_tax_adjustments_called).to be true
      end
    end

    context 'with multiple adjustments from same promotion whose combined discount is larger than item + ship total' do 
      let(:order) { create(:order_with_line_items, line_items_price: 25) }
      let(:promotion) { create(:promotion) }
      let(:source1) { create_source }
      let(:source2) { create_source(percent_calculator) }
      let(:source3) { Spree::Promotion::Actions::FreeShipping.new }
      let(:source4) { create_source }
      let(:percent_calculator) { Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 50) }

      def create_source(calculator=nil)
        Spree::Promotion::Actions::CreateAdjustment.new(calculator: calculator || create(:calculator))
      end

      before do 
        promotion.promotion_actions = [source1, source2, source3, source4]
        promotion.actions.each do |s| 
          s.perform(order: order)
        end       
      end

      it 'calculates the second discount as a percentage of the item total after the first discount is applied' do 
        expect(order.adjustments[1].amount).to eq(-7.5)
      end

      it "calculates discounts that together equal the item + ship total" do
        expect(order.all_adjustments.map(&:amount).reduce(&:+)).to eq(-1 * (order.item_total + order.ship_total))
      end

    end
  end
end
