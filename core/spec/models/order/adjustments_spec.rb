require 'spec_helper'
describe Spree::Order do
  let(:order) { Spree::Order.new }

  context "clear_adjustments" do
    it "should destroy all previous tax adjustments" do
      adjustment = stub
      adjustment.should_receive :destroy

      order.stub_chain :adjustments, :tax => [adjustment]
      order.clear_adjustments!
    end

    it "should destroy all price adjustments" do
      adjustment = stub
      adjustment.should_receive :destroy

      order.stub :price_adjustments => [adjustment]
      order.clear_adjustments!
    end
  end

  context "#price_adjustment_totals" do
    before { @order = Spree::Order.create! }


    context "when there are no price adjustments" do
      before { @order.stub :price_adjustments => [] }

      it "should return an empty hash" do
        @order.price_adjustment_totals.should == {}
      end
    end

    context "when there are two adjustments with different labels" do
      let(:adj1) { mock_model Spree::Adjustment, :amount => 10, :label => "Foo" }
      let(:adj2) { mock_model Spree::Adjustment, :amount => 20, :label => "Bar" }

      before do
        @order.stub :price_adjustments => [adj1, adj2]
      end

      it "should return exactly two totals" do
        @order.price_adjustment_totals.size.should == 2
      end

      it "should return the correct totals" do
        @order.price_adjustment_totals["Foo"].should == 10
        @order.price_adjustment_totals["Bar"].should == 20
      end
    end

    context "when there are two adjustments with one label and a single adjustment with another" do
      let(:adj1) { mock_model Spree::Adjustment, :amount => 10, :label => "Foo" }
      let(:adj2) { mock_model Spree::Adjustment, :amount => 20, :label => "Bar" }
      let(:adj3) { mock_model Spree::Adjustment, :amount => 40, :label => "Bar" }

      before do
        @order.stub :price_adjustments => [adj1, adj2, adj3]
      end

      it "should return exactly two totals" do
        @order.price_adjustment_totals.size.should == 2
      end
      it "should return the correct totals" do
        @order.price_adjustment_totals["Foo"].should == 10
        @order.price_adjustment_totals["Bar"].should == 60
      end
    end
  end

  context "#price_adjustments" do
    before do
      @order = Spree::Order.create!
      @order.stub :line_items => [line_item1, line_item2]
    end

    let(:line_item1) { create(:line_item, :order => @order) }
    let(:line_item2) { create(:line_item, :order => @order) }

    context "when there are no line item adjustments" do
      it "should return nothing if line items have no adjustments" do
        @order.price_adjustments.should be_empty
      end
    end

    context "when only one line item has adjustments" do
      before do
        @adj1 = line_item1.adjustments.create({:amount => 2, :source => line_item1, :label => "VAT 5%"}, :without_protection => true)
        @adj2 = line_item1.adjustments.create({:amount => 5, :source => line_item1, :label => "VAT 10%"}, :without_protection => true)
      end

      it "should return the adjustments for that line item" do
         @order.price_adjustments.should =~ [@adj1, @adj2]
      end
    end

    context "when more than one line item has adjustments" do
      before do
        @adj1 = line_item1.adjustments.create({:amount => 2, :source => line_item1, :label => "VAT 5%"}, :without_protection => true)
        @adj2 = line_item2.adjustments.create({:amount => 5, :source => line_item2, :label => "VAT 10%"}, :without_protection => true)
      end

      it "should return the adjustments for each line item" do
        @order.price_adjustments.should == [@adj1, @adj2]
      end
    end
  end
end

