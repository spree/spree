require 'spec_helper'

describe Spree::StockMovement do
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.first }
  subject { build(:stock_movement, stock_item: stock_item) }

  it 'should belong to a stock item' do
    subject.should respond_to(:stock_item)
  end

  context "when quantity is negative" do
    context "after save" do
      it "should decrement the stock item count on hand" do
        subject.quantity = -1
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 9
      end
    end

    context "after an update" do
      it "should decrement the stock item count on hand based on previous value" do
        subject.quantity = -1
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 9
        subject.quantity = -3
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 7
      end

      it "should increment the stock item count on hand based on previous value" do
        subject.quantity = -3
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 7
        subject.quantity = -1
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 9
      end
    end
  end

  context "when quantity is positive" do
    context "after save" do
      it "should increment the stock item count on hand" do
        subject.quantity = 1
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 11
      end
    end

    context "after an update" do
      it "should increment the stock item count on hand based on previous value" do
        subject.quantity = 1
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 11
        subject.quantity = 3
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 13
      end

      it "should decrement the stock item count on hand based on previous value" do
        subject.quantity = 3
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 13
        subject.quantity = 1
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 11
      end
    end
  end
end
