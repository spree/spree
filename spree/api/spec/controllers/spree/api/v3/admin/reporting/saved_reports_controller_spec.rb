require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Reporting::SavedReportsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  let(:query) { { 'metrics' => %w[gross_revenue orders_count], 'dimensions' => %w[channel], 'sort' => '-gross_revenue' } }
  let!(:report) { create(:saved_report, store: store, name: 'Sales by channel', query: query) }

  describe 'GET #index' do
    it "lists the store's saved reports" do
      create(:saved_report, store: create(:store), name: 'Elsewhere', query: query)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |r| r['name'] }).to eq(['Sales by channel'])
      expect(json_response['data'].first['id']).to start_with('sq_')
    end
  end

  describe 'POST #create' do
    it 'saves a compilable query and records the author' do
      post :create, params: { name: 'Top products', query: { metrics: %w[net_revenue], dimensions: %w[product], limit: 10 } }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['query']['metrics']).to eq(%w[net_revenue])
      expect(json_response['seeded']).to be false
      expect(json_response['author_name']).to be_present
    end

    it 'rejects a query the registry cannot compile' do
      post :create, params: { name: 'Broken', query: { metrics: %w[gross_revenue], dimensions: %w[category] } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('cannot be grouped')
    end
  end

  describe 'PATCH #update / DELETE #destroy' do
    it 'refuses to edit a built-in report' do
      seeded = create(:saved_report, store: store, name: 'Built in', query: query, seeded: true)

      patch :update, params: { id: seeded.prefixed_id, name: 'Renamed' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'updates the name and query' do
      patch :update, params: { id: report.prefixed_id, name: 'Sales by market', query: query.merge('dimensions' => %w[market]) }, as: :json

      expect(response).to have_http_status(:ok)
      expect(report.reload.query['dimensions']).to eq(%w[market])
    end

    it 'destroys the report' do
      delete :destroy, params: { id: report.prefixed_id }, as: :json
      expect(response).to have_http_status(:no_content)
      expect(Spree::SavedReport.exists?(report.id)).to be false
    end

    it "returns 404 for another store's report" do
      foreign = create(:saved_report, store: create(:store), name: 'Elsewhere', query: query)
      patch :update, params: { id: foreign.prefixed_id, name: 'x' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'secret key scopes' do
    let(:headers) { { 'x-spree-api-key' => create(:api_key, :secret, store: store, scopes: %w[read_reports]).plaintext_token } }

    it 'reads with read_reports but needs write_reports to create' do
      get :index, as: :json
      expect(response).to have_http_status(:ok)

      post :create, params: { name: 'Nope', query: query }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
