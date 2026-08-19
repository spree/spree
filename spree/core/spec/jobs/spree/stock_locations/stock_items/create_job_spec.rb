require 'spec_helper'

module Spree
  describe StockLocations::StockItems::CreateJob, :job do
    let!(:stock_location) { create :stock_location }
    let!(:variant) { create :variant }

    # Subclassing rather than aliasing is what lets a job enqueued under the old
    # class name before the deploy still deserialize and run.
    it 'is a subclass of the renamed job' do
      expect(described_class.superclass).to eq(Spree::StockLocations::StockLevels::CreateJob)
    end

    it 'inherits the renamed queue' do
      expect { described_class.perform_later(stock_location) }.to(
        have_enqueued_job.on_queue(Spree.queues.stock_location_stock_levels)
      )
    end

    it 'warns and still does the work when performed' do
      expect(Spree::Deprecation).to receive(:warn).with(/StockLevels::CreateJob/)
      stock_location.stock_levels.unscope(:where).delete_all

      expect { described_class.perform_now(stock_location) }.
        to change { stock_location.stock_levels.count }.from(0)
    end
  end
end
