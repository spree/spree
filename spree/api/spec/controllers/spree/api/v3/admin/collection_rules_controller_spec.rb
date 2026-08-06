require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CollectionRulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #types' do
    it 'lists every registered rule kind with its wire type and label' do
      get :types, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      types = json_response['data']

      expect(types.map { |type| type['type'] }).to match_array(%w[tag sale available_on])
      expect(types.map { |type| type['label'] }).to all(be_present)
      # Sorted by label for stable picker ordering.
      expect(types.map { |type| type['label'] }).to eq(types.map { |type| type['label'] }.sort)
    end

    it 'includes a rule kind registered by a plugin' do
      stub_const('MyPlugin::CollectionRules::Colour', Class.new(Spree::CollectionRule))
      allow(Rails.application.config.spree).to receive(:collection_rules).
        and_return(Rails.application.config.spree.collection_rules + [MyPlugin::CollectionRules::Colour])

      get :types, params: {}, as: :json

      expect(json_response['data'].map { |type| type['type'] }).to include('colour')
    end
  end
end
