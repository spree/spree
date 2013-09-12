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
        line_item.tax_total.should == 0.5
      end
    end

    context "taxes and promotions" do
      pending "calculates item taxes properly after promotions"
    end

    context "best promotion is always applied" do
      let(:calculator) { Calculator::FlatRate.new(:preferred_amount => 10) }

      let(:source) { Promotion::Actions::CreateItemAdjustments.create calculator: calculator }

      def create_adjustment(label, amount)
        create(:adjustment, :order      => order,
                            :adjustable => line_item,
                            :source     => source,
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
          line_item.adjustments.promotion.first.label.should == 'Promotion A'
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
  end
end
