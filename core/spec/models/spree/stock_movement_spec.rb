require 'spec_helper'

describe Spree::StockItem do
  let(:stock_item) { create(:stock_item, stock_location: create(:stock_location)) }
  subject { create(:stock_movement, :sold, stock_item: stock_item) }

  it 'should belong to a stock item' do
    subject.should respond_to(:stock_item)
  end
end
