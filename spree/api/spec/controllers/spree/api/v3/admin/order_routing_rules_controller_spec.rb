require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrderRoutingRulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  # Channels seed 3 default rules on create (preferred_location,
  # minimize_splits, default_location) — specs below lean on that seed.
  let(:channel) { store.default_channel }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the channel rules ordered by position' do
      get :index, params: { channel_id: channel.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      data = json_response[:data]
      expect(data.map { |r| r[:type] }).to eq(%w[preferred_location minimize_splits default_location])
      expect(data.map { |r| r[:position] }).to eq([1, 2, 3])
    end

    it "404s when listing rules of another store's channel" do
      foreign_channel = create(:store).default_channel

      get :index, params: { channel_id: foreign_channel.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'appends a rule at the end of the list when no position is given' do
      channel.order_routing_rules.find_by(type: 'Spree::OrderRouting::Rules::DefaultLocation').destroy!

      post :create, params: { channel_id: channel.prefixed_id, type: 'default_location' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response[:position]).to eq(3)
      expect(json_response[:type]).to eq('default_location')
      expect(json_response[:channel_id]).to eq(channel.prefixed_id)
    end

    it '422s on an unregistered type' do
      post :create, params: { channel_id: channel.prefixed_id, type: 'bogus_rule' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response[:error][:code]).to eq('unknown_order_routing_rule_type')
    end

    it '422s when the channel already has a rule of that kind' do
      post :create, params: { channel_id: channel.prefixed_id, type: 'default_location' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response[:error][:details][:type]).to be_present
      expect(channel.order_routing_rules.count).to eq(3)
    end

    it "404s for a channel that belongs to another store" do
      foreign_channel = create(:store).default_channel

      post :create, params: { channel_id: foreign_channel.prefixed_id, type: 'default_location' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(foreign_channel.order_routing_rules.count).to eq(3)
    end
  end

  describe 'PATCH #update' do
    let(:rule) { channel.order_routing_rules.ordered.first }

    it 'toggles active' do
      patch :update, params: { channel_id: channel.prefixed_id, id: rule.prefixed_id, active: false }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:active]).to be(false)
      expect(rule.reload.active).to be(false)
    end

    it 'reorders the list when position changes' do
      patch :update, params: { channel_id: channel.prefixed_id, id: rule.prefixed_id, position: 3 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(channel.order_routing_rules.ordered.map(&:type)).to eq(
        %w[Spree::OrderRouting::Rules::MinimizeSplits
           Spree::OrderRouting::Rules::DefaultLocation
           Spree::OrderRouting::Rules::PreferredLocation]
      )
    end

    it 'cannot switch the STI type' do
      patch :update, params: { channel_id: channel.prefixed_id, id: rule.prefixed_id, type: 'minimize_splits' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(rule.reload.type).to eq('Spree::OrderRouting::Rules::PreferredLocation')
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the rule from the channel' do
      rule = channel.order_routing_rules.ordered.last

      delete :destroy, params: { channel_id: channel.prefixed_id, id: rule.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(channel.order_routing_rules.count).to eq(2)
    end
  end

  describe 'GET #types' do
    it 'enumerates registered rule kinds with labels and preference schemas' do
      get :types, as: :json

      types = json_response[:data]
      expect(types.map { |t| t[:type] }).to contain_exactly('preferred_location', 'minimize_splits', 'default_location')
      entry = types.find { |t| t[:type] == 'default_location' }
      expect(entry[:label]).to eq('Default location')
      expect(entry[:description]).to be_present
      expect(entry[:preference_schema]).to eq([])
    end

    context 'with a read-only secret API key and no JWT' do
      let(:headers) { api_key_headers }
      let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: ['read_settings']) }

      it 'maps type discovery to the read scope' do
        get :types, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'still requires the write scope for mutations' do
        post :create, params: { channel_id: channel.prefixed_id, type: 'default_location' }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
