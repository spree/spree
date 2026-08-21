require 'spec_helper'

# What an operator needs from the orders list once a checkout can divide:
# which seller a row belongs to, which purchase it was part of, and the
# ability to narrow to either.
RSpec.describe Spree::Api::V3::Admin::OrdersController, 'marketplace columns and filters', type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
  let(:other_seller) { create(:seller, :approved, store: store, name: 'Quill Books') }
  let(:group) { create(:order_group, store: store) }

  let!(:seller_order) do
    create(:order, store: store, order_group: group, seller: seller, status: 'placed', completed_at: Time.current)
  end
  let!(:first_party_order) do
    create(:order, store: store, order_group: group, status: 'placed', completed_at: Time.current)
  end
  let!(:unrelated_order) do
    create(:order, store: store, seller: other_seller, status: 'placed', completed_at: Time.current)
  end

  before { request.headers.merge!(headers) }

  def rows
    json_response['data']
  end

  def row_for(order)
    rows.find { |row| row['number'] == order.number }
  end

  describe 'GET #index' do
    it 'names the seller on each row' do
      get :index, as: :json

      expect(row_for(seller_order)['seller_id']).to eq(seller.prefixed_id)
    end

    it 'carries the whole profile when asked to expand it' do
      get :index, params: { expand: 'seller' }, as: :json

      expect(row_for(seller_order)['seller']['name']).to eq('Sparks Audio')
    end

    it 'leaves the operator’s own order without a seller' do
      get :index, as: :json

      expect(row_for(first_party_order)['seller_id']).to be_nil
      expect(row_for(first_party_order)['seller']).to be_nil
    end

    it 'names the purchase a row was part of' do
      get :index, as: :json

      expect(row_for(seller_order)['order_group_id']).to eq(group.prefixed_id)
    end

    it 'leaves an ungrouped order without a purchase' do
      get :index, as: :json

      expect(row_for(unrelated_order)['order_group_id']).to be_nil
    end
  end

  # The dashboard's filters send prefixed ids, which is what its autocomplete
  # and its links carry — so that is what these assert on.
  describe 'filtering' do
    it 'narrows to one seller' do
      get :index, params: { q: { seller_id_eq: seller.prefixed_id } }, as: :json

      expect(rows.map { |row| row['number'] }).to contain_exactly(seller_order.number)
    end

    it 'narrows to several sellers at once, as the picker sends them' do
      get :index, params: { q: { seller_id_in: [seller.prefixed_id, other_seller.prefixed_id] } }, as: :json

      expect(rows.map { |row| row['number'] }).to contain_exactly(seller_order.number, unrelated_order.number)
    end

    it 'narrows to the orders of one purchase' do
      get :index, params: { q: { order_group_id_eq: group.prefixed_id } }, as: :json

      expect(rows.map { |row| row['number'] }).to contain_exactly(seller_order.number, first_party_order.number)
    end
  end
end
