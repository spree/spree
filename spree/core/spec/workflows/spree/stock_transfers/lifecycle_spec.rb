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

    def receive(items = nil, **attributes)
      Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload, items: items, **attributes)
    end

    def line
      transfer.reload.items.sole
    end

    it 'lands everything as a receipt and closes the trip when the count matches' do
      result = receive(reference: 'Van 3, morning run')

      expect(result).to be_success
      receipt = result.value
      expect(receipt).to be_a(Spree::StockReceipt)
      expect(receipt.reference).to eq('Van 3, morning run')
      expect(receipt.items.sole).to have_attributes(line: line, quantity_accepted: 10)
      expect(transfer.reload).to be_received
      expect(transfer.received_at).to be_present
      expect(destination_on_hand).to eq(10)
      expect(transfer.stock_movements.received.sole.stock_receipt).to eq(receipt)
    end

    it 'lands only what arrived and stays open while units are still on the road' do
      result = receive([{ item: line, quantity_accepted: 8 }])

      expect(result).to be_success
      expect(transfer.reload).to be_partially_received
      expect(transfer.received_at).to be_nil
      expect(destination_on_hand).to eq(8)
      expect(line).to have_attributes(quantity_received: 8, outstanding: 2)
    end

    # Two crushed units arrived all the same: nothing is left in the van, so
    # the trip is over — with the damage on record and off the shelf.
    it 'records what was refused and closes the trip once everything has arrived' do
      result = receive([{ item: line, quantity_accepted: 8, quantity_rejected: 2, rejection_reason: 'damaged' }])

      expect(result).to be_success
      expect(result.value.items.sole).to have_attributes(quantity_accepted: 8, quantity_rejected: 2,
                                                         rejection_reason: 'damaged')
      expect(transfer.reload).to be_received
      expect(transfer.received_at).to be_present
      expect(destination_on_hand).to eq(8)
      expect(line).to have_attributes(quantity_received: 8, quantity_rejected: 2, outstanding: 0)
    end

    # Each delivery adds what it brought; the second box does not restate the
    # first.
    it 'adds a second delivery to the first' do
      receive([{ item: line, quantity_accepted: 8 }])

      result = receive([{ item: line, quantity_accepted: 2 }])

      expect(result).to be_success
      expect(transfer.reload).to be_received
      expect(transfer.stock_receipts.count).to eq(2)
      expect(destination_on_hand).to eq(10)
      expect(transfer.stock_movements.received.sum(:quantity)).to eq(10)
    end

    it 'books more than was shipped and closes the trip as over-received' do
      result = receive([{ item: line, quantity_accepted: 11 }])

      expect(result).to be_success
      expect(transfer.reload).to be_over_received
      expect(line).to have_attributes(quantity_received: 11, quantity_over: 1, outstanding: 0)
      expect(destination_on_hand).to eq(11)
    end

    # Two operators receiving two boxes at once, which the destination's
    # tablet makes as easy as a double-tap: each adds its own count to the
    # total it reads, and the lock makes the second read the first's write.
    it 'adds a delivery to the total another delivery just committed' do
      stale_line = line
      receive([{ item: line, quantity_accepted: 6 }])

      result = receive([{ item: stale_line, quantity_accepted: 4 }])

      expect(result).to be_success
      expect(transfer.reload).to be_received
      expect(destination_on_hand).to eq(10)
    end

    # Two entries for one line are genuinely ambiguous — two cartons, or a
    # correction of the first? — the shape a scanner app produces when it
    # appends an entry per carton.
    it 'refuses a payload that names the same line twice' do
      result = receive([{ item: line, quantity_accepted: 4 }, { item: line, quantity_accepted: 6 }])

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.repeated_item', variant: line.variant_name))
      expect(destination_on_hand).to eq(0)
      expect(line.quantity_received).to eq(0)
    end

    it 'refuses a delivery that counts nothing' do
      result = receive([{ item: line, quantity_accepted: 0 }])

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.no_items_received'))
    end

    it 'refuses a line belonging to another transfer' do
      other_item = create(:stock_transfer, store: store).items.first

      result = receive([{ item: other_item, quantity_accepted: 1 }])

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.item_not_on_document'))
    end

    it 'refuses a transfer that is not on the road' do
      draft = create(:stock_transfer, store: store)

      result = Spree::StockTransfers::Receive.call(stock_transfer: draft)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.not_in_transit'))
    end
  end

  describe 'closing short' do
    before { Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer) }

    it 'ends a partially received trip and records what happened to the rest' do
      Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload,
                                          items: [{ item: transfer.items.sole, quantity_accepted: 8 }])

      result = Spree::StockTransfers::Close.call(stock_transfer: transfer.reload, reason: 'Two fell off the van')

      expect(result).to be_success
      expect(result.value).to be_received
      expect(result.value).to be_closed_short
      expect(result.value.close_reason).to eq('Two fell off the van')
      expect(result.value.items.sole.outstanding).to eq(2)
      expect(source_on_hand).to eq(0)
      expect(destination_on_hand).to eq(8)
    end

    it 'refuses a trip nothing has arrived on' do
      result = Spree::StockTransfers::Close.call(stock_transfer: transfer.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.not_partially_received'))
    end
  end

  describe 'going back to draft' do
    it 'unfreezes a packed transfer' do
      Spree::StockTransfers::MarkReady.call(stock_transfer: transfer)

      result = Spree::StockTransfers::MarkDraft.call(stock_transfer: transfer.reload)

      expect(result).to be_success
      expect(result.value).to be_draft
      expect(result.value).to be_editable
      expect(source_on_hand).to eq(10)
    end

    it 'refuses once the van has left' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)

      result = Spree::StockTransfers::MarkDraft.call(stock_transfer: transfer.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('stock_transfer.errors.not_ready_to_ship'))
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
      expect(transfer.reload.close_reason).to eq('stolen')
      expect(transfer.stock_movements.received).to be_empty
    end

    # Anything the destination already counted in is on its shelf and stays.
    it 'only resolves the units still in flight' do
      Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer)
      Spree::StockTransfers::Receive.call(stock_transfer: transfer.reload,
                                          items: [{ item: transfer.items.sole, quantity_accepted: 6 }])

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
