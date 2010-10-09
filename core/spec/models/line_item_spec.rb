require 'spec_helper'

describe LineItem do
  let(:order) { mock_model(Order, :update! => nil, :completed? => true) }
  let(:line_item) { Fabricate(:line_item, :order => order) }

  context "#save" do
    it "should call order#update!" do
      order.should_receive(:update!)
      line_item.save
    end

    context "when order#completed? is true" do
      it "should not call InventoryUnit#adjust_units" do
        InventoryUnit.should_not_receive(:adjust_units)
        line_item.save
      end
    end

    context "when order#completed? is false" do
      before { order.stub(:completed?).and_return(false) }

      it "should call InventoryUnit#adjust_units" do
        InventoryUnit.should_receive(:adjust_units).with(order).at_least(:once)
        line_item.save
      end
    end

  end

  context "#destroy" do
    context "when order#completed? is true" do
      it "should not call InventoryUnit#adjust_units" do
        InventoryUnit.should_not_receive(:adjust_units)
        line_item.destroy
      end
    end

    context "when order#completed? is false" do
      before { order.stub(:completed?).and_return(false) }

      it "should call InventoryUnit#adjust_units" do
        InventoryUnit.should_receive(:adjust_units).with(order).at_least(:once)
        line_item.destroy
      end
    end

  end
end
