require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PurchaseOrdersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:store) { Spree::Store.default }
  let!(:supplier) { create(:supplier, store: store, name: 'Acme Wholesale') }
  let!(:destination_location) { create(:stock_location, store: store, name: 'Brooklyn') }
  let(:variant) { create(:variant) }

  before { request.headers.merge!(headers) }

  def create_draft(quantity: 100, unit_cost: 12.5)
    Spree::PurchaseOrders::Create.call(
      store: store, supplier: supplier, destination_location: destination_location,
      items: [{ variant: variant, quantity_ordered: quantity, unit_cost: unit_cost }]
    ).value
  end

  def on_hand
    destination_location.stock_level(variant.id)&.count_on_hand.to_i
  end

  describe 'GET #index' do
    let!(:purchase_order) { create_draft }

    it 'returns the store’s purchase orders with their totals' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].find { |po| po['id'] == purchase_order.prefixed_id }
      expect(row).to include(
        'status' => 'draft', 'items_count' => 1, 'quantity_ordered_total' => 100,
        'quantity_received_total' => 0, 'subtotal' => '1250.0', 'editable' => true
      )
      expect(row['supplier_id']).to eq(supplier.prefixed_id)
    end

    it "never lists another store's purchase orders" do
      other_store = create(:store)
      foreign = Spree::PurchaseOrders::Create.call(
        store: other_store, supplier: create(:supplier, store: other_store),
        destination_location: create(:stock_location, store: other_store),
        items: [{ variant: create(:product, store: other_store).default_variant,
                  quantity_ordered: 1, unit_cost: 1 }]
      ).value

      get :index, as: :json

      expect(json_response['data'].map { |po| po['id'] }).not_to include(foreign.prefixed_id)
    end

    it 'filters by status so the dashboard can show only what is outstanding' do
      ordered = create_draft
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: ordered)

      get :index, params: { q: { status_eq: 'ordered' } }, as: :json

      expect(json_response['data'].map { |po| po['id'] }).to eq([ordered.prefixed_id])
    end
  end

  describe 'POST #create' do
    let(:params) do
      {
        supplier_id: supplier.prefixed_id,
        destination_location_id: destination_location.prefixed_id,
        expected_at: '2026-10-01',
        reference: 'SUP-8891',
        items: [{ variant_id: variant.prefixed_id, quantity_ordered: 100, unit_cost: '12.50' }]
      }
    end

    it 'drafts the order without touching availability' do
      expect { post :create, params: params, as: :json }.to change(Spree::PurchaseOrder, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response).to include('status' => 'draft', 'reference' => 'SUP-8891',
                                       'currency' => store.default_currency)
      expect(json_response['number']).to start_with('PO')
      expect(on_hand).to eq(0)
    end

    it 'accepts a foreign currency' do
      post :create, params: params.merge(currency: 'EUR'), as: :json

      expect(json_response['currency']).to eq('EUR')
    end

    it "returns 404 for another store's supplier" do
      foreign_supplier = create(:supplier, store: create(:store))

      post :create, params: params.merge(supplier_id: foreign_supplier.prefixed_id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another store's warehouse" do
      foreign_location = create(:stock_location, store: create(:store))

      post :create, params: params.merge(destination_location_id: foreign_location.prefixed_id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another store's variant" do
      foreign_variant = create(:product, store: create(:store)).default_variant

      post :create, params: params.merge(
        items: [{ variant_id: foreign_variant.prefixed_id, quantity_ordered: 1, unit_cost: '1' }]
      ), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    let!(:purchase_order) { create_draft }

    it 'replaces the lines of a draft' do
      other_variant = create(:variant)

      patch :update, params: {
        id: purchase_order.prefixed_id, reference: 'SUP-9000',
        items: [{ variant_id: other_variant.prefixed_id, quantity_ordered: 4, unit_cost: '3.00' }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['reference']).to eq('SUP-9000')
      line = purchase_order.reload.items.sole
      expect(line.variant).to eq(other_variant)
      expect(line.quantity_ordered).to eq(4)
      expect(line.unit_cost).to eq(3)
    end

    it 'refuses to rewrite an order already placed with the supplier' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)

      patch :update, params: { id: purchase_order.prefixed_id, reference: 'too late' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'the lifecycle actions' do
    let!(:purchase_order) { create_draft }

    it 'places the order with the supplier' do
      patch :mark_ordered, params: { id: purchase_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('status' => 'ordered', 'editable' => false)
      expect(json_response['ordered_at']).to be_present
      expect(on_hand).to eq(0)
    end

    it 'cancels what is outstanding and leaves received units on the shelf' do
      patch :mark_ordered, params: { id: purchase_order.prefixed_id }, as: :json
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: purchase_order.items.sole, quantity_accepted: 60 }])

      patch :cancel, params: { id: purchase_order.prefixed_id, reason: 'Supplier went under' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('canceled')
      expect(on_hand).to eq(60)
    end
    it 'takes a placed order back to draft while nothing has arrived' do
      patch :mark_ordered, params: { id: purchase_order.prefixed_id }, as: :json

      patch :mark_draft, params: { id: purchase_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('status' => 'draft', 'editable' => true)
      expect(json_response['ordered_at']).to be_nil
    end

    it 'refuses to take an order back to draft once a delivery has been booked' do
      patch :mark_ordered, params: { id: purchase_order.prefixed_id }, as: :json
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: purchase_order.items.sole, quantity_accepted: 1 }])

      patch :mark_draft, params: { id: purchase_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'closes a short order and keeps what arrived' do
      patch :mark_ordered, params: { id: purchase_order.prefixed_id }, as: :json
      Spree::PurchaseOrders::Receive.call(purchase_order: purchase_order.reload,
                                          items: [{ item: purchase_order.items.sole, quantity_accepted: 60 }])

      patch :close, params: { id: purchase_order.prefixed_id, reason: 'Supplier out of stock' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('status' => 'received', 'closed_short' => true,
                                       'close_reason' => 'Supplier out of stock')
      expect(on_hand).to eq(60)
    end

    it 'refuses to close an order nothing has arrived on' do
      patch :mark_ordered, params: { id: purchase_order.prefixed_id }, as: :json

      patch :close, params: { id: purchase_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    let!(:purchase_order) { create_draft }

    it 'throws a draft away' do
      expect { delete :destroy, params: { id: purchase_order.prefixed_id }, as: :json }.
        to change(Spree::PurchaseOrder, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'refuses to delete an order already placed' do
      Spree::PurchaseOrders::MarkOrdered.call(purchase_order: purchase_order)

      delete :destroy, params: { id: purchase_order.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('invalid_status')
    end
  end

  describe 'expanding the document' do
    let!(:purchase_order) { create_draft }

    it 'returns the lines with their costs when asked' do
      get :show, params: { id: purchase_order.prefixed_id, expand: 'items,supplier' }, as: :json

      expect(response).to have_http_status(:ok)
      line = json_response['items'].sole
      expect(line).to include('quantity_ordered' => 100, 'unit_cost' => '12.5',
                              'display_unit_cost' => '$12.50', 'outstanding' => 100)
      expect(json_response['supplier']['name']).to eq('Acme Wholesale')
    end
  end
end
