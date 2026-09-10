require 'spec_helper'

# Buying stock in: nothing counts toward availability until units actually
# land, and what they cost is recorded on the movement that lands them.
describe 'purchase order lifecycle', type: :model do
  let(:store) { Spree::Store.default }
  let(:supplier) { create(:supplier, store: store) }
  let(:destination) { create(:stock_location, store: store) }
  let(:variant) { create(:variant) }

  let(:purchase_order) do
    Spree::PurchaseOrders::Create.call(
      store: store,
      supplier: supplier,
      destination_location: destination,
      expected_at: 2.weeks.from_now.to_date,
      items: [{ variant: variant, quantity_ordered: 100, unit_cost: 12.5 }]
    ).value
  end

  def on_hand
    destination.stock_level(variant.id)&.count_on_hand.to_i
  end

  describe 'creating' do
    it 'drafts the order without buying anything' do
      expect(purchase_order).to be_draft
      expect(purchase_order.supplier).to eq(supplier)
      expect(purchase_order.currency).to eq(store.default_currency)
      expect(purchase_order.items.sole).to have_attributes(quantity_ordered: 100, unit_cost: 12.5)
      expect(on_hand).to eq(0)
    end

    # See the twin note in the stock transfer lifecycle spec: the model's
    # after_commit hook owns this announcement.
    it 'leaves announcing a new order to the model' do
      published = []
      allow_any_instance_of(Spree::PurchaseOrder).
        to receive(:publish_event) { |_instance, name, *| published << name }

      Spree::PurchaseOrders::Create.call(
        store: store, supplier: supplier, destination_location: destination,
        items: [{ variant: variant, quantity_ordered: 1, unit_cost: 1 }]
      )

      expect(published).not_to include('purchase_order.created')
    end

    it 'refuses a line with no quantity' do
      result = Spree::PurchaseOrders::Create.call(
        store: store, supplier: supplier, destination_location: destination,
        items: [{ variant: variant, quantity_ordered: 0, unit_cost: 1 }]
      )

      expect(result).to be_failure
    end
  end

  describe 'placing the order' do
    it 'freezes the lines and stamps when it went out' do
      result = Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)

      expect(result).to be_success
      expect(result.value).to be_ordered
      expect(result.value.ordered_at).to be_present
      expect(result.value).not_to be_editable
    end

    # A merchant who has ordered stock does not have it.
    it 'still leaves availability alone' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)

      expect(on_hand).to eq(0)
    end

    it 'refuses an order that has already gone out' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)

      result = Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.not_draft'))
    end
  end

  describe 'receiving' do
    before { Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order) }

    def receive(items = nil, **attributes)
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload, items: items, **attributes)
    end

    def line
      purchase_order.reload.items.sole
    end

    it 'books the whole delivery in as a receipt and closes the order' do
      result = receive

      expect(result).to be_success
      receipt = result.value
      expect(receipt).to be_a(Spree::StockReceipt)
      expect(receipt.number).to start_with('SR')
      expect(receipt.items.sole).to have_attributes(line: line, quantity_accepted: 100, quantity_rejected: 0)
      expect(purchase_order.reload).to be_received
      expect(purchase_order.received_at).to be_present
      expect(on_hand).to eq(100)
    end

    it 'records what the units cost on the movement that landed them, and which delivery' do
      receipt = receive.value

      movement = purchase_order.reload.stock_movements.sole
      expect(movement).to have_attributes(kind: 'received', quantity: 100, unit_cost: 12.5)
      expect(movement.purchase_order).to eq(purchase_order)
      expect(movement.stock_receipt).to eq(receipt)
      expect(movement.display_unit_cost.to_s).to eq('$12.50')
    end

    it 'adds each delivery to the line and keeps the order open until it is whole' do
      first = receive([{ item: line, quantity_accepted: 60 }], reference: 'DN-1')
      expect(purchase_order.reload).to be_partially_received
      expect(line).to have_attributes(quantity_received: 60, outstanding: 40)

      second = receive([{ item: line, quantity_accepted: 40 }], reference: 'DN-2')

      expect(purchase_order.reload).to be_received
      expect(purchase_order.stock_receipts.order(:id).map(&:reference)).to eq(%w[DN-1 DN-2])
      expect(first.value.quantity_accepted_total).to eq(60)
      expect(second.value.quantity_accepted_total).to eq(40)
      expect(on_hand).to eq(100)
    end

    it 'records each delivery at the cost agreed when it landed' do
      receive([{ item: line, quantity_accepted: 60 }])
      line.update!(unit_cost: 14.0)
      receive([{ item: line, quantity_accepted: 40 }])

      costs = purchase_order.reload.stock_movements.order(:id).map { |movement| [movement.quantity, movement.unit_cost] }
      expect(costs).to eq([[60, 12.5], [40, 14.0]])
    end

    it 'keeps rejected units off the shelf and on the receipt' do
      result = receive([{ item: line, quantity_accepted: 8, quantity_rejected: 2, rejection_reason: 'damaged' }])

      expect(result).to be_success
      expect(result.value.items.sole).to have_attributes(quantity_rejected: 2, rejection_reason: 'damaged')
      expect(line).to have_attributes(quantity_received: 8, quantity_rejected: 2, outstanding: 92)
      expect(on_hand).to eq(8)
    end

    it 'refuses a rejection that gives no reason' do
      result = receive([{ item: line, quantity_accepted: 8, quantity_rejected: 2 }])

      expect(result).to be_failure
      expect(on_hand).to eq(0)
    end

    it 'books an over-shipment in and closes the order as over-received' do
      result = receive([{ item: line, quantity_accepted: 110 }])

      expect(result).to be_success
      expect(purchase_order.reload).to be_over_received
      expect(purchase_order).to be_closed
      expect(line).to have_attributes(quantity_received: 110, quantity_over: 10, outstanding: 0)
      expect(on_hand).to eq(110)
    end

    it 'refuses a delivery that counts nothing' do
      result = receive([{ item: line, quantity_accepted: 0, quantity_rejected: 0 }])

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.no_items_received'))
    end

    # Two entries for one line are genuinely ambiguous — two cartons, or a
    # correction of the first? — the shape a scanner app produces when it
    # appends an entry per pallet.
    it 'refuses a payload that names the same line twice' do
      result = receive([{ item: line, quantity_accepted: 40 }, { item: line, quantity_accepted: 60 }])

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.repeated_item', variant: line.variant_name))
      expect(on_hand).to eq(0)
    end

    # Two receivers booking two pallets at once: each adds its own count to
    # the total it reads, and the lock makes the second read the first's write.
    it 'adds a delivery to the total another delivery just committed' do
      stale_line = line
      receive([{ item: line, quantity_accepted: 60 }])

      result = receive([{ item: stale_line, quantity_accepted: 40 }])

      expect(result).to be_success
      expect(line.quantity_received).to eq(100)
      expect(on_hand).to eq(100)
    end

    it 'refuses a negative count' do
      result = receive([{ item: line, quantity_accepted: -1 }])

      expect(result).to be_failure
      expect(on_hand).to eq(0)
    end

    it 'refuses a line belonging to another order' do
      other_item = create(:purchase_order, store: store).items.first

      result = receive([{ item: other_item, quantity_accepted: 1 }])

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.item_not_on_document'))
    end

    it 'refuses an order that has not been placed' do
      draft = create(:purchase_order, store: store)

      result = Spree::PurchaseOrders::Receive.call(purchase_order: draft)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.not_ordered'))
    end
  end

  describe 'closing short' do
    before { Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order) }

    it 'ends a partially received order and records why' do
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: purchase_order.items.sole, quantity_accepted: 60 }])

      result = Spree::PurchaseOrders::Close.call(purchase_order: purchase_order.reload,
                                                 reason: 'Supplier out of stock')

      expect(result).to be_success
      expect(result.value).to be_received
      expect(result.value).to be_closed_short
      expect(result.value.close_reason).to eq('Supplier out of stock')
      expect(result.value.items.sole.outstanding).to eq(40)
      expect(on_hand).to eq(60)
    end

    it 'refuses an order nothing has arrived on' do
      result = Spree::PurchaseOrders::Close.call(purchase_order: purchase_order.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.not_partially_received'))
    end
  end

  describe 'going back to draft' do
    before { Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order) }

    it 'reopens a placed order nothing has arrived on' do
      result = Spree::PurchaseOrders::MarkDraft.call(purchase_order: purchase_order.reload)

      expect(result).to be_success
      expect(result.value).to be_draft
      expect(result.value.ordered_at).to be_nil
      expect(result.value).to be_editable
    end

    it 'refuses once a delivery has been booked' do
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: purchase_order.items.sole, quantity_accepted: 1 }])

      result = Spree::PurchaseOrders::MarkDraft.call(purchase_order: purchase_order.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.already_receiving'))
    end
  end

  describe 'the supplier order count' do
    it 'tracks purchase orders without counting them per row' do
      expect { purchase_order }.to change { supplier.reload.purchase_orders_count }.from(0).to(1)

      purchase_order.destroy

      expect(supplier.reload.purchase_orders_count).to eq(0)
    end
  end

  describe 'cancelling' do
    # A purchase order never moved stock, so there is nothing to unwind — and
    # units already received stay on the shelf, because the merchant has them.
    it 'closes what is outstanding and leaves received units alone' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: purchase_order.items.sole, quantity_accepted: 60 }])

      result = Spree::PurchaseOrders::Cancel.call(purchase_order: purchase_order.reload,
                                                  reason: 'Supplier went under')

      expect(result).to be_success
      expect(result.value).to be_canceled
      expect(result.value.notes).to include('Supplier went under')
      expect(on_hand).to eq(60)
    end

    it 'cancels a draft that never got any lines' do
      empty = create(:purchase_order, store: store, quantity: 0)

      result = Spree::PurchaseOrders::Cancel.call(purchase_order: empty)

      expect(result).to be_success
      expect(result.value).to be_canceled
    end

    it 'refuses an order that is already over' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload)

      result = Spree::PurchaseOrders::Cancel.call(purchase_order: purchase_order.reload)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.already_closed'))
    end
  end

  describe 'editing' do
    it 'replaces the lines of a draft' do
      other_variant = create(:variant)

      result = Spree::PurchaseOrders::Update.call(
        purchase_order: purchase_order,
        attributes: { reference: 'SUP-8891' },
        items: [{ variant: other_variant, quantity_ordered: 4, unit_cost: 3 }]
      )

      expect(result).to be_success
      expect(result.value.reference).to eq('SUP-8891')
      expect(result.value.items.sole).to have_attributes(variant: other_variant, quantity_ordered: 4)
    end

    it 'refuses to rewrite an order already placed with the supplier' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)

      result = Spree::PurchaseOrders::Update.call(purchase_order: purchase_order.reload,
                                                  attributes: { reference: 'too late' })

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.not_editable'))
    end
  end
end
