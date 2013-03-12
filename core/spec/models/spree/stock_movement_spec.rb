require 'spec_helper'

describe Spree::StockMovement do
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.first }
  subject { build(:stock_movement, stock_item: stock_item) }

  it 'should belong to a stock item' do
    subject.should respond_to(:stock_item)
  end

  it 'can set the action to sold' do
    subject.save.should be_true
  end

  it 'can set the action to received' do
    subject.action = 'received'
    subject.save.should be_true
  end

  it 'cannot set the action unless it is sold/received' do
    subject.action = 'invalid'
    subject.save.should be_false
    subject.errors.messages[:action].should include("invalid is not a valid action")
  end

  context "when action is sold" do
    context "after save" do
      it "should decrement the stock item count on hand" do
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 9
      end
    end

    context "after an update" do
      it "should decrement the stock item count on hand based on previous value" do
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 9
        subject.quantity = 3
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 7
      end

      it "should increment the stock item count on hand based on previous value" do
        subject.quantity = 3
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 7
        subject.quantity = 1
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 9
      end
    end
  end

  context "when action is received" do
    context "after save" do
      it "should increment the stock item count on hand" do
        subject.action = 'received'
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 11
      end
    end

    context "after an update" do
      it "should increment the stock item count on hand based on previous value" do
        subject.action = 'received'
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 11
        subject.quantity = 3
        subject.save
        stock_item.reload
        stock_item.count_on_hand.should == 13
      end

      it "should decrement the stock item count on hand based on previous value" do
        subject.action = 'received'
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
