require_relative '../../../app/models/spree/order_components/line_items.rb'
require 'fakes/order'
require 'fakes/line_item'

module Spree
  class FakeOrder
    include Spree::OrderComponents::LineItems

    def build_line_item(*attributes)
       FakeLineItem.new(*attributes)
    end
  end
end

describe Spree::OrderComponents::LineItems do
  let(:order) { Spree::FakeOrder.new }
  let(:variant_1) { stub(:product => "product 1", :id => 1) }
  let(:variant_2) { stub(:product => "product 2", :id => 2) }
  it "#products" do
    line_items = [stub(:variant => variant_1), stub(:variant => variant_2)]
    order.stub(:line_items => line_items)
    order.products.should == ['product 1', 'product 2']
  end

  context "#contains?" do
    before do
      line_items = [stub(:variant_id => variant_1.id)]
      order.stub :line_items => line_items
    end

    specify do
      order.contains?(variant_1).should be_true
      order.contains?(variant_2).should be_false
    end
  end

  context "#quantity_of" do
    before do
      order.stub :line_items => [stub(:variant_id => variant_1.id, :quantity => 1)]
    end

    specify do
      order.quantity_of(variant_1).should == 1

      variant_3 = stub(:id => 3)
      order.quantity_of(variant_3).should == 0
    end
  end

  context "#amount" do
    before do
      order.stub :line_items => [stub(:amount => 10), stub(:amount => 20)]
    end

    specify do
      order.amount.should == 30.0
    end
  end

  context "#add_variant" do
    before do
      variant_1.stub :price => 10
    end

    it "adds a new line item if one doesn't already exist" do
      order.line_items.should == []
      line_item = order.add_variant(variant_1)

      order.line_items.count.should == 1
      order.line_items.first.variant.should == variant_1

      line_item.quantity.should == 1
      line_item.price.should == variant_1.price
      line_item.variant.should == variant_1
    end

    it "uses an existing line item if it already exists" do
      line_item = Spree::FakeLineItem.new(:variant_id => variant_1.id, :quantity => 1)
      order.line_items << line_item
      order.add_variant(variant_1)

      line_item.quantity.should == 2
    end
  end

  context "#item_count" do
    before do
      order.stub :line_items => [stub(:quantity => 5), stub(:quantity => 1)]
    end

    specify do
      order.item_count.should == 6
    end

  end
end



    # it "can find a line item matching a given variant" do
    #   order.find_line_item_by_variant(@variant1).should_not be_nil
    #   order.find_line_item_by_variant(mock_model(Spree::Variant)).should be_nil
    # end
