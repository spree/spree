require "spec_helper"

describe Spree::CreateStockItemsJob do
  include ActiveJob::TestHelper

  let(:stock_location) { create :stock_location }
  let!(:variant) { create :variant }

  it "can enqueue a job after creating a stock location" do
    stock_location.send :create_stock_items
    expect(enqueued_jobs.size).to eq 1
  end

  it "should create stock items for the given stock location" do
    subject.perform stock_location.id
    expect(stock_location.stock_items).to_not be_empty
  end
end
