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

      context 'given a stock item' do
        it 'can increase count on hand given a variant' do
          subject.increase_stock_for_variant(variant, 5)
          subject.count_on_hand(variant).should eq 15
        end

        it 'can decrease count on hand given a variant' do
          subject.decrease_stock_for_variant(variant, 5)
          subject.count_on_hand(variant).should eq 5
        end
      end
  end
end
