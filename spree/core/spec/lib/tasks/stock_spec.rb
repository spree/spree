require 'spec_helper'
require 'rake'

describe 'spree:stock' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'stock.rake')
  end

  describe 'recount_levels' do
    subject(:run_task) { Rake::Task['spree:stock:recount_levels'].tap(&:reenable).invoke }

    let(:store) { Spree::Store.default }
    let(:destination) { create(:stock_location, store: store) }
    let(:variant) { create(:variant) }
    let(:level) { destination.stock_level_or_create(variant) }

    def order_from_supplier(quantity)
      purchase_order = Spree::PurchaseOrders::Create.call(
        store: store, supplier: create(:supplier, store: store), destination_location: destination,
        items: [{ variant: variant, quantity_ordered: quantity, unit_cost: 1 }]
      ).value
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order).value
    end

    it 'puts a drifted level back to what its sources say' do
      order_from_supplier(20)
      create(:stock_reservation, stock_level: level, quantity: 3, expires_at: 5.minutes.from_now)
      create(:stock_reservation, stock_level: level, quantity: 9, expires_at: 1.minute.ago)
      level.update_columns(reserved_count: 12, incoming_count: 0)

      expect { run_task }.to output(/reserved 12 → 3, incoming 0 → 20/).to_stdout

      expect(level.reload).to have_attributes(reserved_count: 3, incoming_count: 20)
    end

    it 'clears a figure whose source is gone' do
      level.update_columns(reserved_count: 5, incoming_count: 8)

      run_task

      expect(level.reload).to have_attributes(reserved_count: 0, incoming_count: 0)
    end

    # The writers create the destination level when the warehouse has never
    # held the SKU; the backfill has to do the same or the page stays blank.
    it 'creates the level an open order is bound for' do
      purchase_order = order_from_supplier(15)
      purchase_order.destination_location.stock_level(variant.id).delete

      run_task

      expect(destination.stock_level(variant.id).incoming_count).to eq(15)
    end

    it 'leaves a correct level alone and reports nothing' do
      order_from_supplier(20)

      expect { run_task }.to output(/Corrected 0 stock level/).to_stdout
      expect(level.reload.incoming_count).to eq(20)
    end
  end
end
