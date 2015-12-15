require 'spec_helper'

describe Spree::Admin::StockTransfersController, type: :controller do
  stub_authorization!

  let(:stock_location_a) { create(:stock_location) }
  let(:stock_location_b) { create(:stock_location) }
  let(:stock_location_c) { create(:stock_location) }
  let(:stock_location_d) { create(:stock_location) }

  let!(:stock_transfer1) do
    Spree::StockTransfer.create!(
      source_location:      stock_location_a,
      destination_location: stock_location_b
    )
  end

  let!(:stock_transfer2) do
    Spree::StockTransfer.create!(
      source_location:      stock_location_c,
      destination_location: stock_location_d
    )
  end

  context '#index' do
    it 'gets all transfers without search criteria' do
      spree_get(:index)

      expect(assigns(:stock_transfers).count).to be(2)
    end

    it 'searches by source location' do
      spree_get(:index, q: { source_location_id_eq: stock_location_a.id })

      expect(assigns(:stock_transfers).to_a).to eql([stock_transfer1])
    end

    it 'searches by destination location' do
      spree_get(:index, q: { destination_location_id_eq: stock_location_d.id })

      expect(assigns(:stock_transfers).to_a).to eql([stock_transfer2])
    end
  end
end
