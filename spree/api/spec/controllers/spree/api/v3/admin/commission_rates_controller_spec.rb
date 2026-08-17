require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CommissionRatesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:rate) { create(:commission_rate, store: store, name: 'Standard', value: 10) }
  let(:vendor) { create(:vendor, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store rates with their targeting' do
      create(:commission_rule, commission_rate: rate, subject: vendor)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('crate_')
      expect(row['name']).to eq('Standard')
      expect(row['kind']).to eq('percentage')
      expect(row['rules'].first).to include('subject_type' => 'Spree::Vendor', 'subject_name' => vendor.name)
    end

    it "hides another marketplace's rates" do
      other = create(:commission_rate, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'refuses a rate belonging to another store' do
      other = create(:commission_rate, store: create(:store))

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a rate with its targeting in one request' do
      post :create, params: {
        name: 'Audio sellers',
        kind: 'percentage',
        value: 12.5,
        rules: [{ subject_type: 'Spree::Vendor', subject_id: vendor.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['value']).to eq('12.5')
      expect(json_response['rules'].first['subject_id']).to eq(vendor.prefixed_id)
    end

    it 'refuses a fixed rate with no currency' do
      post :create, params: { name: 'Flat', kind: 'fixed', value: 2 }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH #update' do
    it 'replaces the targeting wholesale' do
      create(:commission_rule, commission_rate: rate, subject: vendor)
      other_vendor = create(:vendor, store: store)

      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ subject_type: 'Spree::Vendor', subject_id: other_vendor.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rate.reload.commission_rules.map(&:subject)).to eq([other_vendor])
    end

    # Refused rather than filtered: `rules` replaces the whole targeting, so
    # dropping the bad row would leave a rate with no rules — and a rate with
    # no rules charges every seller. Silently widening what the client meant to
    # narrow is the worst available outcome.
    it 'refuses a rule naming another store record, leaving the targeting alone' do
      create(:commission_rule, commission_rate: rate, subject: vendor)
      foreign_vendor = create(:vendor, store: create(:store))

      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ subject_type: 'Spree::Vendor', subject_id: foreign_vendor.prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(rate.reload.commission_rules.map(&:subject)).to eq([vendor])
    end

    it 'refuses a rule naming a type that cannot be targeted' do
      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ subject_type: 'Spree::Order', subject_id: create(:order, store: store).prefixed_id }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a rule naming a record that no longer exists' do
      patch :update, params: {
        id: rate.prefixed_id,
        rules: [{ subject_type: 'Spree::Vendor', subject_id: 'ven_gone' }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'still accepts an empty list as clearing the targeting' do
      create(:commission_rule, commission_rate: rate, subject: vendor)

      patch :update, params: { id: rate.prefixed_id, rules: [] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rate.reload.commission_rules).to be_empty
    end
  end

  describe 'reordering' do
    # The list is the precedence, so moving a row is how an operator changes
    # which rate wins.
    it 'moves a rate through the list' do
      top = create(:commission_rate, store: store)

      patch :update, params: { id: rate.prefixed_id, position: 1 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(store.commission_rates.ordered.to_a).to eq([rate, top])
    end
  end

  describe 'DELETE #destroy' do
    it 'removes a rate' do
      delete :destroy, params: { id: rate.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CommissionRate.where(id: rate.id)).to be_empty
    end
  end

  describe 'GET #rule_subject_types' do
    it 'tells the dashboard what a rule may target' do
      get :rule_subject_types, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['type'] }).
        to match_array(['Spree::Product', 'Spree::Category', 'Spree::Vendor'])
    end
  end
end
