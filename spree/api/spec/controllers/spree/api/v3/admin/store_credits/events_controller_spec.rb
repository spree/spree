require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StoreCredits::EventsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:customer) { create(:user) }
  let!(:store_credit) { create(:store_credit, store: store, customer: customer, amount: 50, currency: 'USD') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, params: { store_credit_id: store_credit.prefixed_id }, as: :json }

    it "lists the credit's ledger" do
      subject

      expect(response).to have_http_status(:ok)
      actions = json_response['data'].map { |event| event['action'] }
      expect(actions).to include(Spree::StoreCredit::ALLOCATION_ACTION)
    end

    it 'describes each entry with its amount and display string' do
      subject

      entry = json_response['data'].first
      expect(entry['amount']).to eq('50.0')
      expect(entry['display_amount']).to match(/\$50\.00/)
      expect(entry['store_credit_id']).to eq(store_credit.prefixed_id)
      expect(entry['created_at']).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it 'reports the originator as a polymorphic shorthand' do
      gift_card = create(:gift_card, store: store, amount: 50, currency: 'USD')
      store_credit.update!(action: Spree::StoreCredit::ALLOCATION_ACTION, action_originator: gift_card, amount: 60)

      subject

      entry = json_response['data'].find { |event| event['originator_type'].present? }
      expect(entry['originator_type']).to eq('gift_card')
      expect(entry['originator_id']).to eq(gift_card.prefixed_id)
    end

    it 'returns the newest entry first' do
      store_credit.update!(action: Spree::StoreCredit::CAPTURE_ACTION, action_amount: 10, amount_used: 10)

      subject

      timestamps = json_response['data'].map { |event| event['created_at'] }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it '404s for a credit belonging to another store' do
      other = create(:store_credit, store: create(:store), amount: 25)

      get :index, params: { store_credit_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
