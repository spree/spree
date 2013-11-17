require 'spec_helper'

describe Spree::StockMovement do
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.order(:id).first }
  subject { build(:stock_movement, stock_item: stock_item) }

  it 'should belong to a stock item' do
    subject.should respond_to(:stock_item)
  end

  it 'is readonly unless new' do
    subject.save
    expect {
      subject.save
    }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it 'does not update count on hand when track inventory levels is false' do
    Spree::Config[:track_inventory_levels] = false
    subject.quantity = 1
    subject.save
    stock_item.reload
    stock_item.count_on_hand.should == 10
  end

  it 'does not update count on hand when variant inventory tracking is off' do
    stock_item.variant.track_inventory = false
    subject.quantity = 1
    subject.save
    stock_item.reload
    stock_item.count_on_hand.should == 10
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
  end
end
