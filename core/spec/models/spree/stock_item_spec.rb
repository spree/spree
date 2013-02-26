require 'spec_helper'

describe Spree::StockItem do
  let(:stock_location) { create(:stock_location) }
  subject { create(:stock_item, stock_location: stock_location) }

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
end
