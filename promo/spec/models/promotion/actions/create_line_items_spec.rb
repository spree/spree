require 'spec_helper'

describe Spree::Promotion::Actions::CreateLineItems do
  let(:order) { Factory(:order) }
  let(:promotion) { Spree::Promotion.new }
  let(:action) { Spree::Promotion::Actions::CreateLineItems.create }

  context "#perform" do
    before do
      @v1 = Factory(:variant)
      @v2 = Factory(:variant)
      action.promotion_action_line_items.create!({
        :variant => @v1,
        :quantity => 1}, :without_protection => true
      )
      action.promotion_action_line_items.create!({
        :variant => @v2,
        :quantity => 2}, :without_protection => true
      )
    end

    it "adds line items to order with correct variant and quantity" do
      action.perform(:order => order)
      order.line_items.count.should == 2
      order.line_items.first.variant.should == @v1
      order.line_items.first.quantity.should == 1
    end

    it "only adds the delta of quantity to an order" do
      order.add_variant(@v2, 1)
      action.perform(:order => order)
      order.line_items.first.variant.should == @v2
      order.line_items.first.quantity.should == 2
    end

    it "doesn't add if the quantity is greater" do
      order.add_variant(@v2, 3)
      action.perform(:order => order)
      order.line_items.first.variant.should == @v2
      order.line_items.first.quantity.should == 3
    end
  end

  context "#line_items_string" do
    before do
      action.promotion_action_line_items.create!(
        :variant_id => 10,
        :quantity => 1
      )
      action.promotion_action_line_items.create!(
        :variant_id => 20,
        :quantity => 2
      )
    end
    it "is a string of comma separated pairs of {variant_id}x{quantity}" do
      action.line_items_string.should == '10x1,20x2'
    end
  end

  context "#line_items_string=" do

    before do
      @v1 = Factory(:variant)
      @v2 = Factory(:variant)
    end

    it "creates promotion_action_line_items with matching variant and quantity for each pair in the string" do
      action.line_items_string = "#{@v1.id}x1,#{@v2.id}x2"
      action.promotion_action_line_items.count.should == 2
      action.promotion_action_line_items.first.variant.should == @v1
      action.promotion_action_line_items.first.quantity.should == 1
    end

    it "replaces existing promotion_action_line_items records" do
      action.line_items_string = "#{@v1.id}x1"
      action.line_items_string = "#{@v1.id}x1"
      action.promotion_action_line_items.count.should == 1
    end

    it "ignores bad values in the string" do
      action.line_items_string = " 99x1 , #{@v1.id}x, #{@v1.id} x 1 "
      action.promotion_action_line_items.count.should == 1
    end

  end

end

