require_relative '../../../app/models/spree/order_components/adjustments'
require 'fakes/model/callbacks'
require 'fakes/order'
require 'fakes/line_item'

module Spree
  class Order
    include Spree::OrderComponents::Adjustments
  end
end

describe Spree::OrderComponents::Adjustments do
  let(:order) { Spree::Order.new }
  let(:line_item_1) { Spree::LineItem.new }
  let(:line_item_2) { Spree::LineItem.new }

  before do
    order.line_items = [line_item_1, line_item_2]
  end

  context "#price_adjustments" do
    it "should return nothing if line items have no adjustments" do
      order.price_adjustments.should be_empty
    end

    context "when only one line item has adjustments" do
      let(:adjustment_1) { stub(:adjustment_1) }
      let(:adjustment_2) { stub(:adjustment_2) }

      before do
        line_item_1.adjustments = [adjustment_1, adjustment_2]
      end

      it "should return the adjustments for that line item" do
        order.price_adjustments.should =~ [adjustment_1, adjustment_2]
      end
    end

    context "when more than one line item has adjustments" do
      let(:adjustment_1) { stub(:adjustment_1) }
      let(:adjustment_2) { stub(:adjustment_2) }

      before do
        line_item_1.adjustments = [adjustment_1]
        line_item_2.adjustments = [adjustment_2]
      end

      it "should return the adjustments for each line item" do
        order.price_adjustments.should == [adjustment_1, adjustment_2]
      end
    end
  end

  context "#price_adjustment_totals" do
    context "when there are no price adjustments" do
      it "should return an empty hash" do
        order.price_adjustment_totals.should == {}
      end
    end

    context "when there are two adjustments with different labels" do
      let(:adjustment_1) { stub(:amount => 10, :label => "Foo") }
      let(:adjustment_2) { stub(:amount => 20, :label => "Bar") }

      before do
        order.stub :price_adjustments => [adjustment_1, adjustment_2]
      end

      it "should return exactly two totals" do
        order.price_adjustment_totals.size.should == 2
      end

      it "should return the correct totals" do
        order.price_adjustment_totals["Foo"].should == 10
        order.price_adjustment_totals["Bar"].should == 20
      end
    end

    context "when there are two adjustments with one label and a single adjustment with another" do

      let(:adjustment_1) { stub(:amount => 10, :label => "Foo") }
      let(:adjustment_2) { stub(:amount => 20, :label => "Bar") }
      let(:adjustment_3) { stub(:amount => 40, :label => "Bar") }

      before do
        order.stub :price_adjustments => [adjustment_1, adjustment_2, adjustment_3]
      end

      it "should return exactly two totals" do
        order.price_adjustment_totals.size.should == 2
      end

      it "should return the correct totals" do
        order.price_adjustment_totals["Foo"].should == 10
        order.price_adjustment_totals["Bar"].should == 60
      end
    end
  end

  context "with adjustments" do
    let(:adjustment_1) { stub(:amount => 5) }
    let(:adjustment_2) { stub(:amount => 10) }

    context "#ship_total" do
      it "should return the correct amount" do
        order.stub_chain :adjustments, :shipping => [adjustment_1, adjustment_2]
        order.ship_total.should == 15
      end
    end

    context "#tax_total" do
      it "should return the correct amount" do
        order.stub_chain :adjustments, :tax => [adjustment_1, adjustment_2]
        order.tax_total.should == 15
      end
    end
  end
end
