require 'spec_helper'

module Spree

  describe StockLocation do
    subject { create(:stock_location_with_items) }
    let(:stock_item) { subject.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    before(:each) do
      Spree::StockLocation.delete_all
    end

    it 'creates stock_items for all variants' do
      subject.stock_items.count.should eq Variant.count
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

    it 'restocks a variant with a positive stock movement' do
      originator = double
      subject.should_receive(:move).with(variant, 5, originator)
      subject.restock(variant, 5, originator)
    end

    it 'unstocks a variant with a negative stock movement' do
      originator = double
      subject.should_receive(:move).with(variant, -5, originator)
      subject.unstock(variant, 5, originator)
    end

    it 'it creates a stock_movement' do
      expect {
        subject.move variant, 5
      }.to change { subject.stock_movements.where(stock_item_id: stock_item).count }.by(1)
    end

    it 'can be deactivated' do
      create(:stock_location, :active => true)
      create(:stock_location, :active => false)
      Spree::StockLocation.active.count.should eq 1
    end

    context 'fill_status' do
      it 'all on_hand with no backordered' do
        on_hand, backordered = subject.fill_status(variant, 5)
        on_hand.should eq 5
        backordered.should eq 0
      end

      it 'some on_hand with some backordered' do
        on_hand, backordered = subject.fill_status(variant, 20)
        on_hand.should eq 10
        backordered.should eq 10
      end

      it 'zero on_hand with all backordered' do
        zero_stock_item = mock_model(StockItem,
                                     count_on_hand: 0,
                                     backorderable?: true)
        subject.should_receive(:stock_item).with(variant).and_return(zero_stock_item)

        on_hand, backordered = subject.fill_status(variant, 20)
        on_hand.should eq 0
        backordered.should eq 20
      end

      context 'when backordering is not allowed' do
        before do
          @stock_item = mock_model(StockItem, backorderable?: false)
          subject.should_receive(:stock_item).with(variant).and_return(@stock_item)
        end

        it 'all on_hand' do
          @stock_item.stub(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 5)
          on_hand.should eq 5
          backordered.should eq 0
        end

        it 'some on_hand' do
          @stock_item.stub(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 20)
          on_hand.should eq 10
          backordered.should eq 0
        end

        it 'zero on_hand' do
          @stock_item.stub(count_on_hand: 0)

          on_hand, backordered = subject.fill_status(variant, 20)
          on_hand.should eq 0
          backordered.should eq 0
        end
      end
    end
  end

end

