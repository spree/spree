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

    it 'books the whole delivery in and closes the order' do
      result = Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload)

      expect(result).to be_success
      expect(result.value).to be_received
      expect(result.value.received_at).to be_present
      expect(on_hand).to eq(100)
    end

    it 'records what the units cost on the movement that landed them' do
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload)

      movement = purchase_order.reload.stock_movements.sole
      expect(movement).to have_attributes(kind: 'received', quantity: 100, unit_cost: 12.5)
      expect(movement.purchase_order).to eq(purchase_order)
      expect(movement.display_unit_cost.to_s).to eq('$12.50')
    end

    it 'stays open when the supplier under-ships' do
      item = purchase_order.reload.items.sole

      result = Spree::PurchaseOrders::Receive.call(
        purchase_order: purchase_order, items: [{ item: item, quantity_received: 60 }]
      )

      expect(result).to be_success
      expect(result.value).to be_partially_received
      expect(on_hand).to eq(60)
      expect(item.reload.outstanding).to eq(40)
    end

    # Two deliveries agreed at different prices are two movements, each
    # carrying its own cost — which is the whole reason the column exists.
    it 'records each delivery at the price it was agreed' do
      item = purchase_order.reload.items.sole
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order,
                                          items: [{ item: item, quantity_received: 60 }])
      item.reload.update!(unit_cost: 14)

      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: item.reload, quantity_received: 100 }])

      costs = purchase_order.reload.stock_movements.order(:id).map { |m| [m.quantity, m.unit_cost.to_f] }
      expect(costs).to eq([[60, 12.5], [40, 14.0]])
      expect(on_hand).to eq(100)
    end

    it 'refuses to receive more than was ordered' do
      result = Spree::PurchaseOrders::Receive.call(
        purchase_order: purchase_order.reload,
        items: [{ item: purchase_order.items.sole, quantity_received: 101 }]
      )

      expect(result).to be_failure
      expect(on_hand).to eq(0)
    end

    it 'refuses a line belonging to another order' do
      other_item = create(:purchase_order, store: store).items.first

      result = Spree::PurchaseOrders::Receive.call(
        purchase_order: purchase_order.reload, items: [{ item: other_item, quantity_received: 1 }]
      )

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.item_not_on_order'))
    end

    it 'refuses an order that has not been placed' do
      draft = create(:purchase_order, store: store)

      result = Spree::PurchaseOrders::Receive.call(purchase_order: draft)

      expect(result).to be_failure
      expect(result.error.to_s).to eq(Spree.t('purchase_order.errors.not_ordered'))
    end
  end

  describe 'cancelling' do
    # A purchase order never moved stock, so there is nothing to unwind — and
    # units already received stay on the shelf, because the merchant has them.
    it 'closes what is outstanding and leaves received units alone' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: purchase_order.items.sole, quantity_received: 60 }])

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
