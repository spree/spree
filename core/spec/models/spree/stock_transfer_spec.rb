require 'spec_helper'

module Spree
  describe StockTransfer do
    let(:destination_location) { create(:stock_location_with_items) }
    let(:source_location) { create(:stock_location_with_items) }
    let(:stock_item) { source_location.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    subject { StockTransfer.create }

    it 'transfers variants between 2 locations' do
      variants = { variant => 5 }

      subject.transfer(source_location,
                       destination_location,
                       variants)

      source_location.count_on_hand(variant).should eq 5
      destination_location.count_on_hand(variant).should eq 5
      subject.should have(2).stock_movements
    end
  end
end
