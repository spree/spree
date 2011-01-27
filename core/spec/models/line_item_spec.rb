require File.dirname(__FILE__) + '/../spec_helper'

describe LineItem do

  context 'validation' do
    it { should have_valid_factory(:line_item) }
  end

  let(:variant) { mock_model(Variant, :count_on_hand => 95, :price => 9.99) }
  let(:line_item) { line_item = LineItem.new(:quantity => 5) }
  let(:order) { mock_model(Order, :line_items => [line_item], :inventory_units => [], :shipments => mock('shipments'), :completed? => true, :update! => true) }

  before { line_item.stub(:order => order, :variant => variant, :new_record? => false) }

  context "#save" do
    it "should update inventory and totals" do
      InventoryUnit.stub(:increase)
      line_item.should_receive(:update_inventory)
      order.should_receive(:update!)
      line_item.save
    end

    context "when order#completed? is true" do

      context "and line_item is a new record" do
        before { line_item.stub(:new_record? => true) }

        it "should increase inventory" do
          InventoryUnit.stub(:increase)
          InventoryUnit.should_receive(:increase).with(order, variant, 5)
          line_item.save
        end
      end

      context "and quantity is increased" do
        before { line_item.stub(:changed_attributes => {"quantity" => 5}, :quantity => 6) }

        it "should increase inventory" do
          InventoryUnit.should_not_receive(:decrease)
          InventoryUnit.should_receive(:increase).with(order, variant, 1)
          line_item.save
        end
      end

      context "and quantity is decreased" do
        before { line_item.stub(:changed_attributes => {"quantity" => 5}, :quantity => 3) }

        it "should decrease inventory" do
          InventoryUnit.should_not_receive(:increase)
          InventoryUnit.should_receive(:decrease).with(order, variant, 2)
          line_item.save
        end
      end

      context "and quantity is not changed" do

        it "should not manager inventory" do
          InventoryUnit.should_not_receive(:increase)
          InventoryUnit.should_not_receive(:decrease)
          line_item.save
        end
      end


    end

    context "when order#completed? is false" do
      before { order.stub(:completed? => false) }

      it "should not manage inventory" do
        InventoryUnit.should_not_receive(:increase)
        InventoryUnit.should_not_receive(:decrease)
        line_item.save
      end
    end

  end

  context "#destroy" do
    context "when order.completed? is true" do
      it "should remove inventory" do
        InventoryUnit.should_receive(:decrease).with(order, variant, 5)
        line_item.destroy
      end
    end

    context "when order.completed? is false" do
      before { order.stub(:completed? => false) }

      it "should not remove inventory" do
        InventoryUnit.should_not_receive(:decrease)
      end

    end


    context "with inventory units" do
      let(:inventory_unit) { mock_model(LineItem, :variant_id => variant.id, :shipped? => false) }
      before do
        order.stub(:inventory_units => [inventory_unit])
        line_item.stub(:order => order, :variant_id => variant.id)
      end

      it "should allow destroy when no units have shipped" do
        line_item.should_receive(:remove_inventory)
        line_item.destroy.should be_true
      end

      it "should not allow destroy when units have shipped" do
        inventory_unit.stub(:shipped? => true)
        line_item.should_not_receive(:remove_inventory)
        line_item.destroy.should be_false
      end

    end


  end
end
