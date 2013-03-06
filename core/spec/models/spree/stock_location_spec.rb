require 'spec_helper'

module Spree
  describe StockLocation do
    subject { create(:stock_location) }
    let(:variant) { subject.stock_items.first.variant }

    it 'finds a stock_item for a variant' do
      stock_item = subject.stock_item(variant)
      stock_item.count_on_hand.should eq 10
    end

    it 'finds a count_on_hand for a variant' do
      subject.count_on_hand(variant).should eq 10
    end

    it 'can be deactivated' do
      create(:stock_location, :active => true)
      create(:stock_location, :active => false)
      Spree::StockLocation.active.count.should eq 1
    end
  end
end
