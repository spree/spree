require 'spec_helper'

module Spree
  describe StockLocations::StockItems::CreateJob do
    let!(:stock_location) { create :stock_location }

    it 'enqueues the creation of the stock location stock items' do
      expect { described_class.perform_later(stock_location) }.to have_enqueued_job.on_queue('default')
    end
  end
end
