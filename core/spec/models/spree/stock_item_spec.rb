require 'spec_helper'

describe Spree::StockItem do
  let(:stock_location) { create(:stock_location_with_items) }
  subject { stock_location.stock_items.first }

  it 'maintains the count on hand for a varaint' do
    subject.count_on_hand.should eq 10
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
    subject.variant_name.should == subject.variant.name
  end

  context "count_on_hand=" do
    context "when :track_inventory_levels is true" do
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

  context "#determine_backorder" do
    context "when :track_inventory_levels is true" do
      before { Spree::Config.set :track_inventory_levels => true }

      context "and all units are in stock" do
        it "should return zero back orders" do
          subject.determine_backorder(5).should == 0
        end
      end

      context "and partial units are in stock" do
        before { subject.stub(:count_on_hand).and_return(2) }

        it "should return correct back order amount" do
          subject.determine_backorder(5).should == 3
        end
      end

      context "and zero units are in stock" do
        before { subject.stub(:count_on_hand).and_return(0) }

        it "should return correct back order amount" do
          subject.determine_backorder(5).should == 5
        end
      end

      context "and less than zero units are in stock" do
        before { subject.stub(:count_on_hand).and_return(-9) }

        it "should return entire amount as back order" do
          subject.determine_backorder(5).should == 5
        end
      end
    end

    context "when :track_inventory_levels is false" do
      before { Spree::Config.set :track_inventory_levels => false }

      it "should return zero back orders" do
        subject.determine_backorder(50).should == 0
      end
    end

  end

end
