require 'spec_helper'

module Spree
  describe StockLocation do
    subject { create(:stock_location_with_items) }
    let(:variant) { subject.stock_items.first.variant }

    before(:each) do
      Spree::StockLocation.delete_all
    end

    it 'finds a stock_item for a variant' do
      stock_item = subject.stock_item(variant)
      stock_item.count_on_hand.should eq 10
    end

    it 'finds a count_on_hand for a variant' do
      subject.count_on_hand(variant).should eq 10
    end

    it 'finds determines if you a variant is backorderable' do
      subject.backorderable?(variant).should be_true
    end

    it 'can be deactivated' do
      create(:stock_location, :active => true)
      create(:stock_location, :active => false)
      Spree::StockLocation.active.count.should eq 1
    end

    describe "#find_or_create_stock_item_for_variant" do
      it 'returns existing stock item if present' do
        subject.find_or_create_stock_item_for_variant(variant).should eq subject.stock_items.first
      end

      it 'returns new stock item if one does not already exist' do
        Spree::Variant.skip_callback(:create, :after, :create_stock_items)
        new_variant = create(:variant)
        subject.stock_items.should_receive(:create!)
        subject.find_or_create_stock_item_for_variant(new_variant)
        Spree::Variant.set_callback(:create, :after, :create_stock_items)
      end
    end
  end
end
