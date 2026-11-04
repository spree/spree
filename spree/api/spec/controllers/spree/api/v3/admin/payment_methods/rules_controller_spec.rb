require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PaymentMethods::RulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:payment_method) { create(:check_payment_method, store: store) }
  let(:channel) { create(:channel, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #types' do
    it 'lists registered rule kinds with their preferences schema' do
      get :types, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['type'] }).to contain_exactly(
        'channel_rule', 'market_rule', 'order_total_rule', 'customer_group_rule', 'company_rule'
      )
      company = json_response['data'].find { |row| row['type'] == 'company_rule' }
      expect(company['schema']['properties'].keys).to contain_exactly('company_ids', 'company_orders_only')
    end
  end

  describe 'GET #index' do
    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { payment_method_id: payment_method.prefixed_id }, as: :json }

      let!(:rules) do
        [create(:company_payment_method_rule, payment_method: payment_method),
         create(:market_payment_method_rule, payment_method: payment_method)]
      end
    end

    let!(:rule) { create(:channel_payment_method_rule, payment_method: payment_method, preferred_channel_ids: [channel.id]) }

    it 'lists the rules with prefixed ids in their preferences' do
      get :index, params: { payment_method_id: payment_method.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].sole
      expect(row['type']).to eq('channel_rule')
      expect(row['preferences']).to eq('channel_ids' => [channel.prefixed_id])
    end
  end

  describe 'POST #create' do
    it 'creates a rule from the wire shorthand' do
      post :create, params: {
        payment_method_id: payment_method.prefixed_id,
        type: 'order_total_rule',
        preferences: { min_totals: { USD: '5000.00' } }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['type']).to eq('order_total_rule')
      expect(BigDecimal(payment_method.payment_method_rules.sole.preferred_min_totals['USD'])).to eq(BigDecimal('5000'))
    end

    it 'rejects unregistered types' do
      post :create, params: { payment_method_id: payment_method.prefixed_id, type: 'bogus_rule' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a duplicate rule kind' do
      create(:market_payment_method_rule, payment_method: payment_method)

      post :create, params: { payment_method_id: payment_method.prefixed_id, type: 'market_rule' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a channel from another store' do
      foreign = create(:channel, store: create(:store))

      post :create, params: {
        payment_method_id: payment_method.prefixed_id,
        type: 'channel_rule',
        preferences: { channel_ids: [foreign.prefixed_id] }
      }, as: :json

      expect(response.status).to be_in([404, 422])
      expect(payment_method.payment_method_rules).to be_empty
    end

    it 'does not reach a payment method of another store' do
      foreign = create(:check_payment_method, store: create(:store))

      post :create, params: { payment_method_id: foreign.prefixed_id, type: 'market_rule' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    let!(:rule) { create(:company_payment_method_rule, payment_method: payment_method) }

    it 'turns a rule off and changes its preferences' do
      patch :update, params: {
        payment_method_id: payment_method.prefixed_id,
        id: rule.prefixed_id,
        active: false,
        preferences: { company_orders_only: false }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rule.reload.active).to be(false)
      expect(rule.preferred_company_orders_only).to be(false)
    end
  end

  describe 'DELETE #destroy' do
    let!(:rule) { create(:company_payment_method_rule, payment_method: payment_method) }

    it 'removes the rule' do
      delete :destroy, params: { payment_method_id: payment_method.prefixed_id, id: rule.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(payment_method.reload.payment_method_rules).to be_empty
    end
  end
end
