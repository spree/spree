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
end
