require 'spec_helper'

module Spree
  describe PurchaseOrder, type: :model do
    let(:store) { Spree::Store.default }

    it_behaves_like 'metadata'
    it_behaves_like 'lifecycle events'

    describe 'defaults' do
      subject(:purchase_order) { create(:purchase_order, store: store) }

      it 'opens as a draft with a PO number' do
        expect(purchase_order).to be_draft
        expect(purchase_order.number).to start_with('PO')
      end

      it 'takes the store currency unless told otherwise' do
        expect(purchase_order.currency).to eq(store.default_currency)
        expect(create(:purchase_order, store: store, currency: 'EUR').currency).to eq('EUR')
      end
    end

    describe 'validations' do
      it 'refuses two lines for the same variant' do
        variant = create(:variant)
        purchase_order = build(:purchase_order, store: store)
        purchase_order.items = [
          build(:purchase_order_item, purchase_order: nil, variant: variant),
          build(:purchase_order_item, purchase_order: nil, variant: variant)
        ]

        expect(purchase_order).to be_invalid
        expect(purchase_order.errors[:items]).to include(Spree.t('errors.messages.duplicate_variant'))
      end

      it 'allows an empty draft but not an empty placed order' do
        purchase_order = build(:purchase_order, store: store, quantity: 0)

        expect(purchase_order).to be_valid

        purchase_order.status = 'ordered'
        expect(purchase_order).to be_invalid
      end
    end

    describe '#subtotal' do
      it 'is what the supplier will invoice for everything ordered' do
        purchase_order = create(:purchase_order, store: store, quantity: 0)
        purchase_order.items.create!(variant: create(:variant), quantity_ordered: 10, unit_cost: 12.5)
        purchase_order.items.create!(variant: create(:variant), quantity_ordered: 3, unit_cost: 4)

        expect(purchase_order.subtotal).to eq(137)
        expect(purchase_order.display_subtotal.to_s).to eq('$137.00')
      end
    end

    describe 'items' do
      subject(:item) do
        create(:purchase_order_item, purchase_order: create(:purchase_order, store: store, quantity: 0),
                                     quantity_ordered: 10, quantity_received: 4, unit_cost: 12.5)
      end

      it 'reports what is still owed' do
        expect(item.quantity_expected).to eq(10)
        expect(item.outstanding).to eq(6)
        expect(item).to be_under_received
      end

      it 'costs the whole line at the agreed unit price' do
        expect(item.total_cost).to eq(125)
        expect(item.display_unit_cost.to_s).to eq('$12.50')
      end

      # A receive of twelve against ten ordered is a miscount at the dock, so
      # the error belongs on the value the caller sent.
      it 'refuses to receive more than was ordered' do
        item.quantity_received = 11

        expect(item).to be_invalid
        expect(item.errors[:quantity_received]).to be_present
      end
    end
  end
end
