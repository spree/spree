require 'spec_helper'
require 'rake'

# The upgrade path every existing install takes: 5.x recorded a supplier
# receive as a stock transfer with no source location, and 6.0 has a purchase
# order for that. Legacy rows are written with `insert` and `update_columns`
# because the 6.0 model refuses to build them — which is the point.
describe 'spree:upgrade inventory operations' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'inventory_operations_migration.rake')
  end

  let(:store) { Spree::Store.default }
  let(:destination) { create(:stock_location, store: store) }
  let(:variant) { create(:variant) }

  # A 5.x external receive: no source, no status, no store, and its stock
  # already moved at the time.
  def legacy_external_receive(quantity: 7)
    transfer = create(:stock_transfer, store: store, destination_location: destination, quantity: 0)
    # The cause is set at create time: a movement is readonly once written.
    destination.stock_level_or_create(variant).
      stock_movements.create!(quantity: quantity, kind: 'received', stock_transfer: transfer)
    transfer.update_columns(source_location_id: nil, status: nil, store_id: nil)
    transfer
  end

  describe 'migrate_external_receives_to_purchase_orders' do
    subject(:run_task) { Rake::Task['spree:upgrade:migrate_external_receives_to_purchase_orders'].tap(&:reenable).invoke }

    it 'turns a source-less transfer into a received purchase order' do
      transfer = legacy_external_receive(quantity: 7)

      expect { run_task }.to change(Spree::PurchaseOrder, :count).by(1)

      purchase_order = Spree::PurchaseOrder.last
      expect(purchase_order).to be_received
      expect(purchase_order.supplier.name).to eq('Migrated receives')
      expect(purchase_order.destination_location).to eq(destination)
      expect(purchase_order.received_at).to be_within(1.second).of(transfer.created_at)
      expect(purchase_order.items.sole).to have_attributes(
        variant: variant, quantity_ordered: 7, quantity_received: 7
      )
    end

    # Historical cost is unknowable — nothing recorded it.
    it 'records a zero unit cost' do
      legacy_external_receive

      run_task

      expect(Spree::PurchaseOrder.last.items.sole.unit_cost).to eq(0)
    end

    it 're-points the existing movements at the purchase order' do
      transfer = legacy_external_receive(quantity: 7)
      movement = transfer.stock_movements.sole

      run_task

      expect(movement.reload.purchase_order).to eq(Spree::PurchaseOrder.last)
    end

    # The number has to stay findable for historical reporting, without the
    # same receive showing up twice in the admin.
    it 'soft-deletes the transfer so its number survives' do
      transfer = legacy_external_receive

      run_task

      expect(Spree::StockTransfer.where(id: transfer.id)).to be_empty
      expect(Spree::StockTransfer.only_deleted.find(transfer.id).number).to eq(transfer.number)
    end

    # Those movements already moved the stock, at the time.
    it 'leaves the shelf alone' do
      legacy_external_receive(quantity: 7)
      on_hand = destination.stock_level(variant.id).count_on_hand

      run_task

      expect(destination.stock_level(variant.id).reload.count_on_hand).to eq(on_hand)
    end

    it 'gives every other transfer the store and status the lifecycle expects' do
      internal = create(:stock_transfer, store: store, destination_location: destination)
      internal.update_columns(status: nil, store_id: nil)

      run_task

      expect(internal.reload).to have_attributes(status: 'received', store_id: store.id)
      expect(internal.received_at).to be_present
    end

    it 'is a no-op on a second run' do
      legacy_external_receive
      run_task

      expect { Rake::Task['spree:upgrade:migrate_external_receives_to_purchase_orders'].tap(&:reenable).invoke }.
        not_to change(Spree::PurchaseOrder, :count)
    end

    it 'skips a receive whose movements no longer name a variant' do
      transfer = create(:stock_transfer, store: store, destination_location: destination, quantity: 0)
      transfer.update_columns(source_location_id: nil, status: nil)

      expect { run_task }.not_to change(Spree::PurchaseOrder, :count)
      expect(Spree::StockTransfer.find(transfer.id)).to be_present
    end
  end

  describe 'purge_migrated_external_receives' do
    it 'deletes the transfers the migration soft-deleted' do
      transfer = legacy_external_receive
      Rake::Task['spree:upgrade:migrate_external_receives_to_purchase_orders'].tap(&:reenable).invoke

      Rake::Task['spree:upgrade:purge_migrated_external_receives'].tap(&:reenable).invoke

      expect(Spree::StockTransfer.only_deleted.where(id: transfer.id)).to be_empty
    end

    # Otherwise the movement keeps an `st_…` reference the serializer hands to
    # clients, pointing at a row that no longer exists.
    it 'stops the migrated movements naming the transfer it destroys' do
      transfer = legacy_external_receive
      Rake::Task['spree:upgrade:migrate_external_receives_to_purchase_orders'].tap(&:reenable).invoke
      movement = Spree::StockMovement.find_by(stock_transfer_id: transfer.id)
      expect(movement).to be_present

      Rake::Task['spree:upgrade:purge_migrated_external_receives'].tap(&:reenable).invoke

      expect(movement.reload.stock_transfer_id).to be_nil
      expect(movement.purchase_order).to be_present
    end

    # A transfer still owning its ledger has not been migrated.
    it 'leaves a soft-deleted transfer whose movements are still its own' do
      transfer = legacy_external_receive
      transfer.update_columns(deleted_at: Time.current)

      Rake::Task['spree:upgrade:purge_migrated_external_receives'].tap(&:reenable).invoke

      expect(Spree::StockTransfer.only_deleted.where(id: transfer.id)).to be_present
    end
  end
end
