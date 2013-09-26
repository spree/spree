require 'spec_helper'

describe Spree::StockItem do
  let(:stock_location) { create(:stock_location_with_items) }

  subject { stock_location.stock_items.order(:id).first }

  it 'maintains the count on hand for a variant' do
    subject.count_on_hand.should eq 10
  end

  it "can return the stock item's variant's name" do
    subject.variant_name.should == subject.variant.name
  end

  context "available to be included in shipment" do
    context "has stock" do
      it { subject.should be_available }
    end

    context "backorderable" do
      before { subject.backorderable = true }
      it { subject.should be_available }
    end

    context "no stock and not backorderable" do
      before do
        subject.backorderable = false
        subject.stub(count_on_hand: 0)
      end

      it { subject.should_not be_available }
    end
  end

  context "adjust count_on_hand" do
    let!(:current_on_hand) { subject.count_on_hand }

    it 'is updated pessimistically' do
      copy = Spree::StockItem.find(subject.id)

      subject.adjust_count_on_hand(5)
      subject.count_on_hand.should eq(current_on_hand + 5)

      copy.count_on_hand.should eq(current_on_hand)
      copy.adjust_count_on_hand(5)
      copy.count_on_hand.should eq(current_on_hand + 10)
    end

    context "item out of stock (by two items)" do
      let(:inventory_unit) { double('InventoryUnit') }
      let(:inventory_unit_2) { double('InventoryUnit2') }

      before do
        subject.stub(:backordered_inventory_units => [inventory_unit, inventory_unit_2])
        subject.update_column(:count_on_hand, -2)
      end

      # Regression test for #3755
      it "processes existing backorders, even with negative stock" do
        inventory_unit.should_receive(:fill_backorder)
        inventory_unit_2.should_not_receive(:fill_backorder)
        subject.adjust_count_on_hand(1)
        subject.count_on_hand.should == -1
      end

      # Test for #3755
      it "does not process backorders when stock is adjusted negatively" do
        inventory_unit.should_not_receive(:fill_backorder)
        inventory_unit_2.should_not_receive(:fill_backorder)
        subject.adjust_count_on_hand(-1)
        subject.count_on_hand.should == -3
      end

      context "adds new items" do
        before { subject.stub(:backordered_inventory_units => [inventory_unit, inventory_unit_2]) }

        it "fills existing backorders" do
          inventory_unit.should_receive(:fill_backorder)
          inventory_unit_2.should_receive(:fill_backorder)

          subject.adjust_count_on_hand(3)
          subject.count_on_hand.should == 1
        end
      end
    end
  end

  context "set count_on_hand" do
    let!(:current_on_hand) { subject.count_on_hand }

    it 'is updated pessimistically' do
      copy = Spree::StockItem.find(subject.id)

      subject.set_count_on_hand(5)
      subject.count_on_hand.should eq(5)

      copy.count_on_hand.should eq(current_on_hand)
      copy.set_count_on_hand(10)
      copy.count_on_hand.should eq(current_on_hand)
    end

    context "item out of stock (by two items)" do
      let(:inventory_unit) { double('InventoryUnit') }
      let(:inventory_unit_2) { double('InventoryUnit2') }

      before { subject.set_count_on_hand(-2) }

      it "doesn't process backorders" do
        subject.should_not_receive(:backordered_inventory_units)
      end

      context "adds new items" do
        before { subject.stub(:backordered_inventory_units => [inventory_unit, inventory_unit_2]) }

        it "fills existing backorders" do
          inventory_unit.should_receive(:fill_backorder)
          inventory_unit_2.should_receive(:fill_backorder)

          subject.set_count_on_hand(1)
          subject.count_on_hand.should == 1
        end
      end
    end
  end

  context "with stock movements" do
    before { Spree::StockMovement.create(stock_item: subject, quantity: 1) }

    it "doesnt raise ReadOnlyRecord error" do
      expect { subject.destroy }.not_to raise_error
    end
  end
end
