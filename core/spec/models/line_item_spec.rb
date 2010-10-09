require 'spec_helper'

describe LineItem do
  let(:order) { mock_model(Order, :update! => nil, :completed? => true, :line_items => mock('line-items'), :inventory_units => mock('inventory-units')) }
  let(:line_item) { Fabricate(:line_item, :order => order) }

  context "#save" do
    it "should call order#update!" do
      InventoryUnit.stub(:adjust_units)
      order.should_receive(:update!)
      line_item.save
    end

    context "when order#completed? is true" do
      it "should call InventoryUnit#adjust_units" do
        InventoryUnit.should_receive(:adjust_units).at_least(:once)
        line_item.save
      end
    end

    context "when order#completed? is false" do
      before { order.stub(:completed?).and_return(false) }

      it "should not call InventoryUnit#adjust_units" do
        InventoryUnit.should_not_receive(:adjust_units).with(order)
        line_item.save
      end
    end

  end

  context "#destroy" do
    context "when order#completed? is true" do
      it "should call InventoryUnit#adjust_units" do
        InventoryUnit.should_receive(:adjust_units).at_least(:once)
        line_item.destroy
      end
    end

    context "when order#completed? is false" do
      before { order.stub(:completed?).and_return(false) }

      it "should not call InventoryUnit#adjust_units" do
        InventoryUnit.should_not_receive(:adjust_units).with(order)
        line_item.destroy
      end
    end

  end
end
