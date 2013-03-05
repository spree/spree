require 'spec_helper'

describe Spree::StockItem do
  let(:stock_item) { create(:stock_item, count_on_hand: 10, stock_location: create(:stock_location)) }
  subject { build(:stock_movement, :sold, stock_item: stock_item) }

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
        stock_item.count_on_hand.should == 9
      end
    end
  end

  context "when action is received" do
    context "after save" do
      it "should increment the stock item count on hand" do
        subject.action = 'received'
        subject.save
        stock_item.count_on_hand.should == 11
      end
    end
  end
end
