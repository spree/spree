# coding: UTF-8
require 'spec_helper'

describe Spree::Admin::StockMovementsHelper, :type => :helper do

  describe "#pretty_originator" do

    context "transfering between two locations" do
      let(:destination_location) { create(:stock_location_with_items) }
      let(:source_location) { create(:stock_location_with_items) }
      let(:stock_item) { source_location.stock_items.order(:id).first }
      let(:variant) { stock_item.variant }

      before do
        @stock_transfer = Spree::StockTransfer.create(reference: 'PO123')
        variants = { variant => 5 }
        @stock_transfer.transfer(source_location,
                       destination_location,
                       variants)
        helper.pretty_originator(@stock_transfer.stock_movements.last)
      end


      it "returns link to stock transfer" do
        expect(helper.pretty_originator(@stock_transfer.stock_movements.last)).to eq @stock_transfer.number
      end
    end
  end

end