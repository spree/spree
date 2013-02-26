require 'spec_helper'

module Spree
  module Stock
    describe Package do
      let(:variant) { build(:variant, weight: 25.0) }
      let(:stock_location) { build(:stock_location) }
      let(:order) { build(:order) }

      subject { Package.new(stock_location, order) }

      it 'calculates the weight of all the contents' do
        subject.add variant, 4
        subject.weight.should == 100.0
      end

      it 'filters by on_hand and backordered' do
        subject.add variant, 4, :on_hand
        subject.add variant, 3, :backordered
        subject.on_hand.count.should eq 1
        subject.backordered.count.should eq 1
      end

      it 'calculates the quantity by state' do
        subject.add variant, 4, :on_hand
        subject.add variant, 3, :backordered

        subject.quantity.should eq 7
        subject.quantity(:on_hand).should eq 4
        subject.quantity(:backordered).should eq 3
      end

      it 'returns nil for content item not found' do
        item = subject.find_item(variant, :on_hand)
        item.should be_nil
      end

      it 'finds content item for a variant' do
        subject.add variant, 4, :on_hand
        item = subject.find_item(variant, :on_hand)
        item.quantity.should eq 4
      end

      it 'get flattened contents' do
        subject.add variant, 4, :on_hand
        subject.add variant, 2, :backordered
        flattened = subject.flattened
        flattened.select { |i| i.state == :on_hand }.size.should eq 4
        flattened.select { |i| i.state == :backordered }.size.should eq 2
      end

      it 'set contents from flattened' do
        flattened = [Package::ContentItem.new(variant, 1, :on_hand),
                    Package::ContentItem.new(variant, 1, :on_hand),
                    Package::ContentItem.new(variant, 1, :backordered),
                    Package::ContentItem.new(variant, 1, :backordered)]

        subject.flattened = flattened
        subject.on_hand.size.should eq 1
        subject.on_hand.first.quantity.should eq 2

        subject.backordered.size.should eq 1
      end
    end
  end
end
