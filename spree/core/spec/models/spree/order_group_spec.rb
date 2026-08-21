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
