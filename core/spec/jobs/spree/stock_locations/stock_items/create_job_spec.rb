require 'spec_helper'

module Spree
  describe StockLocations::StockItems::CreateJob, :job do
    let!(:stock_location) { create :stock_location }

    it 'enqueues the creation of the stock location stock items' do
      expect { described_class.perform_later(stock_location) }.to(
        have_enqueued_job.on_queue('spree_stock_location_stock_items')
      )
    end
  end
end
