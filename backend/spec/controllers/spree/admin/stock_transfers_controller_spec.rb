require 'spec_helper'

module Spree
  describe Admin::StockTransfersController, type: :controller do
    stub_authorization!

    let!(:stock_transfer1) do
      StockTransfer.create do |transfer|
        transfer.source_location_id = 1
        transfer.destination_location_id = 2
        transfer.reference = 'PO 666'
      end end

    let!(:stock_transfer2) do
      StockTransfer.create do |transfer|
        transfer.source_location_id = 3
        transfer.destination_location_id = 4
        transfer.reference = 'PO 666'
      end end

    context '#index' do
      it 'gets all transfers without search criteria' do
        spree_get :index
        expect(assigns[:stock_transfers].count).to eq 2
      end

      it 'searches by source location' do
        spree_get :index, q: { source_location_id_eq: 1 }
        expect(assigns[:stock_transfers].count).to eq 1
        expect(assigns[:stock_transfers]).to include(stock_transfer1)
      end

      it 'searches by destination location' do
        spree_get :index, q: { destination_location_id_eq: 4 }
        expect(assigns[:stock_transfers].count).to eq 1
        expect(assigns[:stock_transfers]).to include(stock_transfer2)
      end
    end
  end
end
