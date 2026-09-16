require 'spec_helper'

RSpec.describe Spree::OrderGroup, type: :model do
  let(:store) { @default_store }
  let(:group) { create(:order_group, store: store) }
  let(:seller) { create(:seller, :approved, store: store) }

  it_behaves_like 'metadata'

  describe 'derived money' do
    before do
      create(:order, store: store, order_group: group, total: 30, item_total: 25)
      create(:order, store: store, order_group: group, seller: seller, total: 20, item_total: 18)
    end

    it 'totals what the children came to' do
      expect(group.reload.total).to eq(50)
      expect(group.item_total).to eq(43)
    end
  end

  describe '#fulfillment_status' do
    it 'is nil while no child has one' do
      create(:order, store: store, order_group: group)

      expect(group.reload.fulfillment_status).to be_nil
    end

    it 'reports the shared status when the children agree' do
      2.times { create(:order, store: store, order_group: group, fulfillment_status: 'unfulfilled') }

      expect(group.reload.fulfillment_status).to eq('unfulfilled')
    end

    it 'reports partial when they disagree' do
      create(:order, store: store, order_group: group, fulfillment_status: 'fulfilled')
      create(:order, store: store, order_group: group, fulfillment_status: 'unfulfilled')

      expect(group.reload.fulfillment_status).to eq('partial')
    end

    # A recalled parcel does not describe the whole purchase.
    it 'ignores a canceled child while another is live' do
      create(:order, store: store, order_group: group, fulfillment_status: 'canceled')
      create(:order, store: store, order_group: group, fulfillment_status: 'fulfilled')

      expect(group.reload.fulfillment_status).to eq('fulfilled')
    end

    it 'is canceled only when every child is' do
      2.times { create(:order, store: store, order_group: group, fulfillment_status: 'canceled') }

      expect(group.reload.fulfillment_status).to eq('canceled')
    end
  end

  describe '#fulfillment_groups' do
    # The whole point: "how many orders" and "how many parcels" are different
    # numbers, and a customer is owed the second.
    it 'counts one parcel per warehouse-and-method, not one per child order' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 3)

      expect(group.orders.count).to eq(3)
      expect(group.fulfillment_groups.size).to eq(3)
    end

    it 'collapses the halves of a parcel the split divided' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 3, shared_stock_location: true)

      expect(group.orders.count).to eq(3)
      expect(group.fulfillment_groups.size).to eq(1)
    end

    it 'gives a divided parcel back the whole charge the customer was quoted' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 2, shared_stock_location: true)
      quoted = group.fulfillments.sum(&:discounted_cost)

      expect(group.fulfillment_groups.sole.cost).to eq(quoted)
    end

    it 'carries the goods and the sellers of every half it collapsed' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 2, shared_stock_location: true)
      parcel = group.fulfillment_groups.sole

      expect(parcel.line_items).to match_array(group.line_items)
      expect(parcel.sellers).to match_array(group.sellers)
    end

    it 'names each parcel by the rate the customer chose' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 2)

      expect(group.fulfillment_groups.map(&:name)).to all(be_present)
    end
  end

  describe '#unfulfilled_line_items' do
    it 'is empty when every item travels in a parcel' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 2)

      expect(group.unfulfilled_line_items).to be_empty
    end

    # A download has nothing to ship, and a confirmation organised by parcel
    # would otherwise never mention it.
    it 'names what no parcel carries' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 2)
      digital_order = create(:order, store: store, order_group: group)
      download = create(:line_item, order: digital_order)

      expect(group.reload.unfulfilled_line_items).to match_array([download])
    end
  end

  describe 'facts about the purchase rather than one seller\'s part of it' do
    it 'answers for the locale, the PO number and who to address' do
      group = create(:order_group, :with_parcels, store: store, sellers_count: 2)
      group.orders.each { |order| order.update_columns(locale: 'de', po_number: 'PO-4471') }

      expect(group.reload.locale).to eq('de')
      expect(group.po_number).to eq('PO-4471')
      expect(group.name).to eq(group.bill_address&.full_name || group.ship_address&.full_name)
    end
  end

  describe '#sellers' do
    it 'names the sellers it reached, first-party contributing none' do
      create(:order, store: store, order_group: group)
      create(:order, store: store, order_group: group, seller: seller)

      expect(group.reload.sellers).to contain_exactly(seller)
      expect(group).to be_includes_first_party
    end
  end

  describe 'children' do
    it 'refuses to be destroyed while it holds orders' do
      create(:order, store: store, order_group: group)

      expect(group.reload.destroy).to be false
      expect(group.errors[:base]).to be_present
    end
  end

  describe 'numbering' do
    it 'takes an order-style number' do
      expect(group.number).to start_with('R')
    end
  end
end
