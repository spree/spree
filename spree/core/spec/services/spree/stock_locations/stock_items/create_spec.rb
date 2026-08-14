require 'spec_helper'

module Spree
  describe StockLocations::StockItems::Create do
    subject { described_class }

    let!(:stock_location) { create(:stock_location_with_items) }

    it 'warns that it has been renamed' do
      expect(Spree::Deprecation).to receive(:warn).with(/StockLevels::Create/)

      subject.call(stock_location: stock_location)
    end

    # The work itself only happens in the renamed service, so seeing the levels
    # appear is what proves the shim delegates.
    it 'still creates the missing stock levels' do
      allow(Spree::Deprecation).to receive(:warn)
      stock_location.stock_levels.unscope(:where).delete_all

      expect { subject.call(stock_location: stock_location) }.
        to change { stock_location.stock_levels.count }.from(0).to(Spree::Variant.count)
    end
  end
end
