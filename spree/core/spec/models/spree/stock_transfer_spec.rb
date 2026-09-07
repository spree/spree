require 'spec_helper'

module Spree
  describe StockTransfer, type: :model do
    let(:store) { Spree::Store.default }
    let(:source_location) { create(:stock_location, store: store) }
    let(:destination_location) { create(:stock_location, store: store) }

    let(:stock_transfer) do
      create(:stock_transfer,
             store: store,
             reference: 'PO123',
             source_location: source_location,
             destination_location: destination_location)
    end

    it_behaves_like 'metadata'
    it_behaves_like 'lifecycle events'

    describe 'defaults' do
      it 'opens as a draft with a number' do
        expect(stock_transfer).to be_draft
        expect(stock_transfer.number).to start_with('T')
        expect(stock_transfer.reference).to eq('PO123')
      end

      # The table carried no store until 6.0, which left the admin endpoint
      # unscoped: Spree::Base.for_store falls through to `self` when the store
      # has no matching association.
      it 'takes its store from the destination warehouse when none is given' do
        transfer = described_class.create!(
          source_location: source_location,
          destination_location: destination_location,
          items: [build(:stock_transfer_item, stock_transfer: nil)]
        )

        expect(transfer.store).to eq(destination_location.store)
        expect(described_class.for_store(store)).to include(transfer)
      end
    end

    describe 'validations' do
      it 'refuses a transfer to the location it leaves from' do
        transfer = build(:stock_transfer, source_location: source_location,
                                          destination_location: source_location)

        expect(transfer).to be_invalid
        expect(transfer.errors[:source_location]).to include(Spree.t('stock_transfer.errors.same_location'))
      end

      # Two locations from different stores would take units out of one
      # tenant's inventory and put them into another's.
      it 'refuses two warehouses belonging to different stores' do
        other_store_location = create(:stock_location, store: create(:store))
        transfer = build(:stock_transfer, source_location: source_location,
                                          destination_location: other_store_location)

        expect(transfer).to be_invalid
        expect(transfer.errors[:destination_location]).to include(
          Spree.t('stock_transfer.errors.locations_in_different_stores')
        )
      end

      it 'refuses two lines for the same variant' do
        variant = create(:variant)
        transfer = build(:stock_transfer, source_location: source_location,
                                          destination_location: destination_location)
        transfer.items = [
          build(:stock_transfer_item, stock_transfer: nil, variant: variant),
          build(:stock_transfer_item, stock_transfer: nil, variant: variant)
        ]

        expect(transfer).to be_invalid
        expect(transfer.errors[:items]).to include(Spree.t('errors.messages.duplicate_variant'))
      end

      # A draft is a packing list the merchant is still filling in; anything
      # past draft describes a box that physically exists.
      it 'allows an empty draft but not an empty shipped transfer' do
        transfer = build(:stock_transfer, source_location: source_location,
                                          destination_location: destination_location, quantity: 0)

        expect(transfer).to be_valid

        transfer.status = 'in_transit'
        expect(transfer).to be_invalid
      end
    end

    describe 'totals' do
      subject(:transfer) do
        create(:stock_transfer, store: store, source_location: source_location,
                                destination_location: destination_location, quantity: 0)
      end

      before do
        transfer.items.create!(variant: create(:variant), quantity_shipped: 10, quantity_received: 7)
        transfer.items.create!(variant: create(:variant), quantity_shipped: 5, quantity_received: 5)
      end

      it 'sums what was promised and what arrived' do
        expect(transfer.items_count).to eq(2)
        expect(transfer.quantity_expected_total).to eq(15)
        expect(transfer.quantity_received_total).to eq(12)
      end

      it 'is under-received while any line is still owed' do
        expect(transfer).to be_under_received
        expect(transfer).not_to be_fully_received
        expect(transfer.status_after_receive).to eq('partially_received')
      end

      it 'is fully received once every line is complete' do
        transfer.items.each { |item| item.update!(quantity_received: item.quantity_shipped) }
        transfer.items.reset

        expect(transfer).to be_fully_received
        expect(transfer.status_after_receive).to eq('received')
      end
    end

    describe 'scopes' do
      it 'separates the trips still running from the ones that are over' do
        draft = create(:stock_transfer, store: store)
        received = create(:stock_transfer, :received, store: store)

        expect(described_class.open).to include(draft)
        expect(described_class.open).not_to include(received)
        expect(described_class.closed).to include(received)
      end
    end

    describe '#editable?' do
      it 'is true only while the box can still be repacked' do
        expect(create(:stock_transfer, store: store)).to be_editable
        expect(create(:stock_transfer, :ready_to_ship, store: store)).not_to be_editable
      end
    end
  end
end
