require 'spec_helper'

describe Spree::StockItem do
  let(:stock_item) { create(:stock_item, stock_location: create(:stock_location)) }
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
        stock_item.stock_location.should_receive(:decrease_stock_for_variant).with(
          stock_item.variant,
          -subject.quantity
        )
        subject.save
      end
    end
  end

  context "when action is received" do
    context "after save" do
      it "should increment the stock item count on hand" do
        subject.action = 'received'
        stock_item.stock_location.should_receive(:increase_stock_for_variant).with(
          stock_item.variant,
          subject.quantity
        )
        subject.save
      end
    end
  end
end
