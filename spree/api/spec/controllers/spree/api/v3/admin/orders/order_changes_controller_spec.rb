require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::OrderChangesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:completed_order_with_totals, store: store, line_items_count: 2) }
  let(:line_item) { order.line_items.first }

  before { request.headers.merge!(headers) }

  describe 'POST #preview' do
    it 'answers the totals the change would produce and saves nothing' do
      post :preview, params: {
        order_id: order.prefixed_id,
        actions: [{ kind: 'update_item', line_item_id: line_item.prefixed_id, quantity: 3 }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['previous_total']).to eq(Spree::Money::Rounding.format(order.total, order.currency))
      expect(json_response['balance_delta'].to_d).to be_positive
      expect(line_item.reload.quantity).to eq(1)
      expect(order.order_changes).to be_empty
    end

    it 'refuses a line item from another order' do
      other = create(:completed_order_with_totals, store: store)

      post :preview, params: {
        order_id: order.prefixed_id,
        actions: [{ kind: 'remove_item', line_item_id: other.line_items.first.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses a variant from another store' do
      foreign_variant = create(:product, store: create(:store)).default_variant

      post :preview, params: {
        order_id: order.prefixed_id,
        actions: [{ kind: 'add_item', variant_id: foreign_variant.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    # Replacements and restocks belong to exchanges, claims and returns,
    # which check what came back and what is owed first.
    it 'refuses the kinds returns, exchanges and claims make' do
      post :preview, params: {
        order_id: order.prefixed_id,
        actions: [{ kind: 'add_fulfillment', line_item_id: line_item.prefixed_id, variant_id: line_item.variant.prefixed_id, quantity: 5 }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to match(/returns, exchanges and claims/i)
    end

    it 'refuses actions that are not objects' do
      post :preview, params: { order_id: order.prefixed_id, actions: ['x'] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses an action missing what its kind needs' do
      post :preview, params: { order_id: order.prefixed_id, actions: [{ kind: 'update_item', quantity: 2 }] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST #create' do
    it 'applies the change at once when asked to confirm' do
      post :create, params: {
        order_id: order.prefixed_id, confirm: true,
        actions: [{ kind: 'update_item', line_item_id: line_item.prefixed_id, quantity: 2 },
                  { kind: 'remove_item', line_item_id: order.line_items.second.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('confirmed')
      expect(json_response['actions'].map { |action| action['kind'] }).to eq(%w[update_item remove_item])
      expect(json_response['requested_by_id']).to eq(admin_user.prefixed_id)
      expect(order.reload.line_items.map(&:quantity)).to eq([2])
    end

    it 'answers the line each confirmed addition landed on' do
      variant = create(:variant)

      post :create, params: {
        order_id: order.prefixed_id, confirm: true,
        actions: [{ kind: 'add_item', variant_id: variant.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:created)
      added = order.reload.line_items.find_by(variant: variant)
      expect(json_response['actions'].first['line_item_id']).to eq(added.prefixed_id)
    end

    it 'applies a discount with the edit' do
      post :create, params: {
        order_id: order.prefixed_id, confirm: true,
        actions: [{ kind: 'add_discount', label: 'Goodwill', value: '10', value_type: 'percent', line_item_id: line_item.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['actions'].first).to include('kind' => 'add_discount', 'label' => 'Goodwill', 'value' => '10', 'value_type' => 'percent')
      expect(order.reload.discounts.manual.sole.line_item).to eq(line_item)
    end

    it 'refuses a discount value that is not a decimal string' do
      post :create, params: {
        order_id: order.prefixed_id, actions: [{ kind: 'add_discount', label: 'Goodwill', value: 'ten' }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(order.order_changes).to be_empty
    end

    it 'refuses a quantity that is not a whole number' do
      post :create, params: {
        order_id: order.prefixed_id, actions: [{ kind: 'update_item', line_item_id: line_item.prefixed_id, quantity: 3.7 }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(order.order_changes).to be_empty
    end

    it 'keeps metadata as sent, id-looking values included' do
      post :create, params: {
        order_id: order.prefixed_id, metadata: { ticket_id: line_item.prefixed_id },
        actions: [{ kind: 'remove_item', line_item_id: line_item.prefixed_id }]
      }, as: :json

      expect(order.order_changes.sole.metadata).to eq('ticket_id' => line_item.prefixed_id)
    end

    it 'leaves the change requested without confirm' do
      post :create, params: {
        order_id: order.prefixed_id, actions: [{ kind: 'remove_item', line_item_id: line_item.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('requested')
      expect(order.reload.line_items).to include(line_item)
    end

    it 'refuses a draft order, which is edited directly' do
      draft = create(:order_with_line_items, store: store)

      post :create, params: {
        order_id: draft.prefixed_id, confirm: true,
        actions: [{ kind: 'remove_item', line_item_id: draft.line_items.first.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to include('Only a placed order')
    end

    it 'refuses while another change is open' do
      Spree::OrderChanges::Begin.call(order: order)

      post :create, params: {
        order_id: order.prefixed_id, actions: [{ kind: 'remove_item', line_item_id: line_item.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['message']).to include('Another change')
    end
  end

  describe 'GET #index' do
    before do
      2.times do
        Spree::OrderChanges::Apply.call(order: order, actions: [{ kind: 'update_item', line_item: line_item, quantity: 2 }])
      end
    end

    it 'lists the order changes' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(2)
    end

    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { order_id: order.prefixed_id }, as: :json }
    end
  end

  describe 'PATCH #confirm and #cancel' do
    let(:order_change) do
      Spree::OrderChanges::Apply.call(order: order, confirm: false,
                                      actions: [{ kind: 'update_item', line_item: line_item, quantity: 4 }]).value
    end

    it 'confirms a requested change' do
      patch :confirm, params: { order_id: order.prefixed_id, id: order_change.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('confirmed')
      expect(line_item.reload.quantity).to eq(4)
    end

    it 'cancels a requested change' do
      patch :cancel, params: { order_id: order.prefixed_id, id: order_change.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('canceled')
      expect(line_item.reload.quantity).to eq(1)
    end

    it 'cannot reach another order’s change' do
      other = create(:completed_order_with_totals, store: store)

      patch :confirm, params: { order_id: other.prefixed_id, id: order_change.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
