require 'spec_helper'

# The whole point of the 6.0 transfer: a trip has a middle. Stock leaves the
# source when the van goes and lands at the destination when somebody counts
# it in, and in between the units belong to neither shelf.
describe 'stock transfer lifecycle', type: :model do
  let(:store) { Spree::Store.default }
  let(:source) { create(:stock_location, store: store) }
  let(:destination) { create(:stock_location, store: store) }
  let(:variant) { create(:variant) }

  let(:transfer) do
    Spree::StockTransfers::Create.call(
      store: store,
      source_location: source,
      destination_location: destination,
      items: [{ variant: variant, quantity_shipped: 10 }]
    ).value
  end

  def source_on_hand
    source.stock_level(variant.id)&.count_on_hand.to_i
  end

  def destination_on_hand
    destination.stock_level(variant.id)&.count_on_hand.to_i
  end

  before { source.restock(variant, 10) }

  describe 'creating' do
    it 'plans the trip without moving anything' do
      expect(transfer).to be_draft
      expect(transfer.items.first).to have_attributes(variant: variant, quantity_shipped: 10,
                                                      quantity_received: 0)
      expect(source_on_hand).to eq(10)
      expect(destination_on_hand).to eq(0)
      expect(transfer.stock_movements).to be_empty
    end

    # `publishes_lifecycle_events` already announces a new record, from an
    # after_commit hook that does not run inside a transactional example — so
    # anything seen here came from the workflow, which used to publish the
    # same name a second time and fire every subscriber twice.
    it 'leaves announcing a new transfer to the model' do
      published = []
      allow_any_instance_of(Spree::StockTransfer).
        to receive(:publish_event) { |_instance, name, *| published << name }

      Spree::StockTransfers::Create.call(
        store: store, source_location: source, destination_location: destination,
        items: [{ variant: variant, quantity_shipped: 1 }]
      )

      expect(published).not_to include('stock_transfer.created')
    end

    it 'refuses a line with no quantity' do
      result = Spree::StockTransfers::Create.call(
        store: store, source_location: source, destination_location: destination,
        items: [{ variant: variant, quantity_shipped: 0 }]
      )

      expect(result).to be_failure
    end
  end

  describe 'marking ready' do
    it 'freezes the list without touching stock' do
      result = Spree::StockTransfers::MarkReady.call(stock_transfer: transfer)

      expect(result).to be_success
      expect(result.value).to be_ready_to_ship
      expect(result.value).not_to be_editable
      expect(source_on_hand).to eq(10)
    end

    it 'refuses a transfer that has already shipped' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)

      result = Spree::StockTransfers::MarkReady.call(stock_transfer: transfer.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.not_draft'))
    end
  end

  describe 'marking in transit' do
    subject(:result) { Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer) }

    it 'takes the units off the source shelf and nowhere else' do
      expect(result).to be_success
      expect(result.value).to be_in_transit
      expect(result.value.shipped_at).to be_present

      expect(source_on_hand).to eq(0)
      expect(destination_on_hand).to eq(0)
    end

    it 'writes a shipped movement naming the transfer' do
      result

      movement = transfer.reload.stock_movements.sole
      expect(movement).to have_attributes(kind: 'shipped', quantity: 10)
      expect(movement.stock_transfer).to eq(transfer)
      expect(movement.unit_cost).to be_nil
    end

    # A transfer moves goods, not promises: units another order is waiting for
    # stay promised at the source.
    it 'leaves the source promises intact' do
      level = source.stock_level_or_create(variant)
      level.update_column(:allocated_count, 3)

      result

      expect(level.reload.allocated_count).to eq(3)
    end

    it 'refuses to send more than the source holds' do
      source.stock_level(variant.id).update_column(:count_on_hand, 4)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(
        Spree.t('stock_transfer.errors.variants_unavailable', stock: source.name)
      )
      expect(source_on_hand).to eq(4)
    end

    it 'sends anyway when the merchant forces it' do
      source.stock_level(variant.id).update_column(:count_on_hand, 4)

      forced = Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer, force: true)

      expect(forced).to be_success
      expect(source_on_hand).to eq(-6)
    end
  end

  describe 'receiving' do
    before { Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer) }

    it 'lands everything and closes the trip when the count matches' do
      result = Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload)

      expect(result).to be_success
      expect(result.value).to be_received
      expect(result.value.received_at).to be_present
      expect(destination_on_hand).to eq(10)
    end

    it 'lands only what arrived and stays open when it is short' do
      item = transfer.reload.items.sole

      result = Spree::StockTransfers::Receive.call(
        stock_transfer: transfer,
        items: [{ item: item, quantity_received: 8, discrepancy_reason: 'damaged_in_transit' }]
      )

      expect(result).to be_success
      expect(result.value).to be_partially_received
      expect(result.value.received_at).to be_nil
      expect(destination_on_hand).to eq(8)
      expect(item.reload).to have_attributes(quantity_received: 8, outstanding: 2,
                                             discrepancy_reason: 'damaged_in_transit')
    end

    # The line's quantity_received is a running total, so a second delivery
    # tops it up rather than landing the whole amount again.
    it 'adds only the difference on a second receive' do
      item = transfer.reload.items.sole
      Spree::StockTransfers::Receive.call(stock_transfer: transfer,
                                          items: [{ item: item, quantity_received: 8 }])

      result = Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload,
                                                   items: [{ item: item.reload, quantity_received: 10 }])

      expect(result).to be_success
      expect(result.value).to be_received
      expect(destination_on_hand).to eq(10)
      expect(transfer.reload.stock_movements.received.sum(:quantity)).to eq(10)
    end

    # A second receive that says nothing about the discrepancy must not erase
    # the audit text the first one recorded.
    it 'keeps the recorded discrepancy reason when a later receive omits it' do
      item = transfer.reload.items.sole
      Spree::StockTransfers::Receive.call(
        stock_transfer: transfer,
        items: [{ item: item, quantity_received: 8, discrepancy_reason: 'damaged_in_transit' }]
      )

      Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload,
                                          items: [{ item: item.reload, quantity_received: 9 }])

      expect(item.reload.discrepancy_reason).to eq('damaged_in_transit')
    end

    it 'refuses to receive more than was shipped' do
      result = Spree::StockTransfers::Receive.call(
        stock_transfer: transfer.reload, items: [{ item: transfer.items.sole, quantity_received: 11 }]
      )

      expect(result).to be_failure
      expect(destination_on_hand).to eq(0)
    end

    # Taking units back off the shelf is a correction, which is what a manual
    # adjustment is for.
    it 'refuses to lower a quantity already received' do
      item = transfer.reload.items.sole
      Spree::StockTransfers::Receive.call(stock_transfer: transfer,
                                          items: [{ item: item, quantity_received: 8 }])

      result = Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload,
                                                   items: [{ item: item.reload, quantity_received: 5 }])

      expect(result).to be_failure
      expect(destination_on_hand).to eq(8)
    end

    it 'refuses a line belonging to another transfer' do
      other_item = create(:stock_transfer, store: store).items.first

      result = Spree::StockTransfers::Receive.call(
        stock_transfer: transfer.reload, items: [{ item: other_item, quantity_received: 1 }]
      )

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.item_not_on_transfer'))
    end

    it 'refuses a transfer that has not shipped' do
      draft = create(:stock_transfer, store: store)

      expect(Spree::StockTransfers::Receive.call(stock_transfer: draft)).to be_failure
    end
  end

  describe 'cancelling' do
    it 'is a no-op for stock while the transfer is still a draft' do
      result = Spree::StockTransfers::Cancel.call(stock_transfer: transfer)

      expect(result).to be_success
      expect(result.value).to be_canceled
      expect(source_on_hand).to eq(10)
      expect(transfer.reload.stock_movements).to be_empty
    end

    # `update` assigns the status before validating, so a draft-only guard on
    # the items validation refused to cancel a transfer with no lines — which
    # the new-transfer screen lets a merchant create.
    it 'cancels a draft that never got any lines' do
      empty = create(:stock_transfer, store: store, quantity: 0)

      result = Spree::StockTransfers::Cancel.call(stock_transfer: empty)

      expect(result).to be_success
      expect(result.value).to be_canceled
    end

    # The units are physically gone from the source, so guessing would either
    # invent stock or destroy it.
    it 'refuses to cancel an in-transit transfer without a decision' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)

      result = Spree::StockTransfers::Cancel.call(stock_transfer: transfer.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.in_transit_resolution_required'))
      expect(transfer.reload).to be_in_transit
    end

    it 'puts the units back when the merchant says they came home' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)

      result = Spree::StockTransfers::Cancel.call(stock_transfer: transfer.reload, on_in_transit: 'restock')

      expect(result).to be_success
      expect(source_on_hand).to eq(10)
      expect(destination_on_hand).to eq(0)
      expect(transfer.reload.stock_movements.received.sum(:quantity)).to eq(10)
    end

    # The loss is already in the ledger — the units left when the transfer
    # shipped. What is missing is why.
    it 'records the reason and moves no stock when the units are written off' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)

      result = Spree::StockTransfers::Cancel.call(stock_transfer: transfer.reload,
                                                  on_in_transit: 'write_off', reason: 'stolen')

      expect(result).to be_success
      expect(source_on_hand).to eq(0)
      expect(destination_on_hand).to eq(0)
      expect(transfer.reload.items.sole.discrepancy_reason).to eq('stolen')
      expect(transfer.stock_movements.received).to be_empty
    end

    # Anything the destination already counted in is on its shelf and stays.
    it 'only resolves the units still in flight' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)
      Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload,
                                          items: [{ item: transfer.items.sole, quantity_received: 6 }])

      Spree::StockTransfers::Cancel.call(stock_transfer: transfer.reload, on_in_transit: 'restock')

      expect(destination_on_hand).to eq(6)
      expect(source_on_hand).to eq(4)
    end

    it 'refuses a transfer that is already over' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)
      Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload)

      result = Spree::StockTransfers::Cancel.call(stock_transfer: transfer.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.already_closed'))
    end
  end

  describe 'editing' do
    it 'replaces the lines of a draft' do
      other_variant = create(:variant)

      result = Spree::StockTransfers::Update.call(
        stock_transfer: transfer,
        attributes: { reference: 'Second attempt' },
        items: [{ variant: other_variant, quantity_shipped: 2 }]
      )

      expect(result).to be_success
      expect(result.value.reference).to eq('Second attempt')
      expect(result.value.items.sole).to have_attributes(variant: other_variant, quantity_shipped: 2)
    end

    it 'refuses to rewrite a transfer the warehouse is already acting on' do
      Spree::StockTransfers::MarkReady.call(stock_transfer: transfer)

      result = Spree::StockTransfers::Update.call(stock_transfer: transfer.reload,
                                                  attributes: { reference: 'too late' })

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.not_editable'))
    end
  end
end
