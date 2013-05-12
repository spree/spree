require 'spec_helper'

module Spree
  describe StockTransfer do
    let(:destination_location) { create(:stock_location_with_items) }
    let(:source_location) { create(:stock_location_with_items) }
    let(:stock_item) { source_location.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    subject { StockTransfer.create(reference: 'PO123') }

    its(:reference) { should eq 'PO123' }
    its(:to_param) { should match /T\d+/ }

    it 'transfers variants between 2 locations' do
      variants = { variant => 5 }

      subject.transfer(source_location,
                       destination_location,
                       variants)

      source_location.count_on_hand(variant).should eq 5
      destination_location.count_on_hand(variant).should eq 5
      subject.should have(2).stock_movements

      subject.source_location.should eq source_location
      subject.destination_location.should eq destination_location

      subject.source_movements.first.quantity.should eq -5
      subject.destination_movements.first.quantity.should eq 5
    end

    it 'receive new inventory (from a vendor)' do
      variants = { variant => 5 }

      subject.receive(destination_location, variants)

      destination_location.count_on_hand(variant).should eq 5
      subject.should have(1).stock_movements

      subject.source_location.should be_nil
      subject.destination_location.should eq destination_location
    end
  end
end
