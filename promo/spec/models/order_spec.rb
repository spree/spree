require 'spec_helper'

describe Spree::Order do

  let(:order) { create(:order) }
  let(:updater) { Spree::OrderUpdater.new(order) }

  context "#update_adjustments" do
    let(:originator) do
      originator = Spree::Promotion::Actions::CreateAdjustment.create
      calculator = Spree::Calculator::PerItem.create({:calculable => originator}, :without_protection => true)
      originator.calculator = calculator
      originator.save
      originator
    end

    def create_adjustment(label, amount)
      create(:adjustment, :adjustable => order,
                          :originator => originator,
                          :amount     => amount,
                          :locked     => true,
                          :label      => label)
    end

    it "should make all but the most valuable promotion adjustment ineligible, leaving non promotion adjustments alone" do
      create_adjustment("Promotion A", -100)
      create_adjustment("Promotion B", -200)
      create_adjustment("Promotion C", -300)
      create_adjustment("Some other credit", -500)
      order.adjustments.each {|a| a.update_attribute_without_callbacks(:eligible, true)}

      updater.update_adjustments

      order.adjustments.eligible.promotion.count.should == 1
      order.adjustments.eligible.promotion.first.label.should == 'Promotion C'
    end

    it "should only leave one adjustment even if 2 have the same amount" do
      create_adjustment("Promotion A", -100)
      create_adjustment("Promotion B", -200)
      create_adjustment("Promotion C", -200)

      updater.update_adjustments

      order.adjustments.eligible.promotion.count.should == 1
      order.adjustments.eligible.promotion.first.amount.to_i.should == -200
    end

  end

end

