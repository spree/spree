require 'spec_helper'

describe Spree::StockItem do
  let(:stock_location) { create(:stock_location) }
  subject { create(:stock_item, stock_location: stock_location, variant: create(:variant, :name => "Spree Bag")) }

  it 'maintains the count on hand for a varaint' do
    subject.count_on_hand.should eq 10
  end

  it 'determines all the locations for a varaint' do
    stock_location = create(:stock_location)
    variant = stock_location.stock_items.first.variant
    locations = Spree::StockItem.locations_for_variant(variant)
    locations.should include stock_location
  end

  it "lock_version should prevent stale updates" do
    copy = Spree::StockItem.find(subject.id)

    copy.count_on_hand = 200
    copy.save!

    subject.count_on_hand = 100
    expect { subject.save }.to raise_error ActiveRecord::StaleObjectError

    subject.reload.count_on_hand.should == 200
    subject.count_on_hand = 100
    subject.save

    subject.reload.count_on_hand.should == 100
  end

  it "can return the stock item's variant's name" do
    subject.variant_name.should == "Spree Bag"
  end

  context "count_on_hand=" do
    context "when :track_inventory_levels is true" do
      before { Spree::Config.set :track_inventory_levels => true }
      let(:inventory_unit) { double('InventoryUnit') }
      let(:inventory_unit_2) { double('InventoryUnit2') }

      context "and count is increased" do
        it "should fill backorders" do
          subject.update_column(:count_on_hand, 0)
          subject.stub(:backordered_inventory_units => [inventory_unit, inventory_unit_2])
          inventory_unit.should_receive(:fill_backorder)
          inventory_unit_2.should_receive(:fill_backorder)
          subject.count_on_hand = 2
          subject.save!
          subject.count_on_hand.should == 0
        end

        it "should only fill up to availability in back orders" do
          subject.update_column(:count_on_hand, 0)
          subject.stub(:backordered_inventory_units => [inventory_unit, inventory_unit_2])
          inventory_unit.should_receive(:fill_backorder)
          inventory_unit_2.should_not_receive(:fill_backorder)
          subject.count_on_hand = 1
          subject.save!
          subject.count_on_hand.should == 0
        end
      end

      context "and count is negative" do
        it "should not check for backordered units" do
          subject.should_not_receive(:backordered_inventory_units)
          subject.count_on_hand = -10
          subject.save!
        end
      end
    end
  end
end
