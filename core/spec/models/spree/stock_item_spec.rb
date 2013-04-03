require 'spec_helper'

describe Spree::StockItem do
  let(:stock_location) { create(:stock_location_with_items) }
  subject { stock_location.stock_items.first }

  it 'maintains the count on hand for a varaint' do
    subject.count_on_hand.should eq 10
  end

  it 'count_on_hand is updated pessimistically' do
    copy = Spree::StockItem.find(subject.id)

    subject.adjust_count_on_hand(5)
    subject.count_on_hand.should eq 15

    copy.count_on_hand.should eq 10
    copy.adjust_count_on_hand(5)
    copy.count_on_hand.should eq 20
  end

  it "can return the stock item's variant's name" do
    subject.variant_name.should == subject.variant.name
  end

  context "count_on_hand=" do
    context "when :track_inventory_levels is true" do
      let(:inventory_unit) { double('InventoryUnit') }
      let(:inventory_unit_2) { double('InventoryUnit2') }

      context "and count is increased" do
        it "should fill backorders" do
          subject.adjust_count_on_hand(-10)
          subject.stub(:backordered_inventory_units => [inventory_unit, inventory_unit_2])
          inventory_unit.should_receive(:fill_backorder)
          inventory_unit_2.should_receive(:fill_backorder)
          subject.adjust_count_on_hand(2)
          subject.count_on_hand.should == 0
        end

        it "should only fill up to availability in back orders" do
          subject.adjust_count_on_hand(-10)
          subject.stub(:backordered_inventory_units => [inventory_unit, inventory_unit_2])
          inventory_unit.should_receive(:fill_backorder)
          inventory_unit_2.should_not_receive(:fill_backorder)
          subject.adjust_count_on_hand(1)
          subject.count_on_hand.should == 0
        end
      end

      context "and count is negative" do
        it "should not check for backordered units" do
          subject.should_not_receive(:backordered_inventory_units)
          subject.adjust_count_on_hand(-10)
        end
      end
    end
  end
end

