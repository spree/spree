require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::TaxLinesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }
  let!(:tax_line) do
    create(:tax_line, order: order, line_item: line_item, amount: 1.5, rate: 0.15, label: 'VAT 15%')
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists tax lines' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['label']).to eq('VAT 15%')
      expect(json_response['data'].first['rate']).to eq('0.15')
      expect(json_response['data'].first['line_item_id']).to eq(line_item.prefixed_id)
    end

    it 'exposes the treatment, the jurisdiction and the provider payload' do
      tax_line.update!(taxability_reason: 'standard_rated', country_iso: 'DE',
                       data: { 'jurisdictions' => [{ 'name' => 'DE', 'amount' => '1.5' }] })

      get :index, params: { order_id: order.prefixed_id }, as: :json

      row = json_response['data'].first
      expect(row['taxability_reason']).to eq('standard_rated')
      expect(row['category_code']).to eq('S')
      expect(row['country_iso']).to eq('DE')
      expect(row['state_code']).to be_nil
      expect(row['data']['jurisdictions'].first['name']).to eq('DE')
      expect(row['provider_id']).to eq('internal')
    end

    it 'filters by taxability reason, which is what tax reporting needs' do
      exempt_line = create(:tax_line, order: order, line_item: line_item, amount: 0, rate: 0,
                                      taxability_reason: 'customer_exempt')

      get :index, params: { order_id: order.prefixed_id, q: { taxability_reason_eq: 'customer_exempt' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).to eq([exempt_line.prefixed_id])
    end

    it 'filters by taxing country' do
      tax_line.update!(country_iso: 'DE')
      create(:tax_line, order: order, line_item: line_item, country_iso: 'FR')

      get :index, params: { order_id: order.prefixed_id, q: { country_iso_eq: 'DE' } }, as: :json

      expect(json_response['data'].map { |row| row['id'] }).to eq([tax_line.prefixed_id])
    end
  end

  describe 'GET #show' do
    it 'returns a tax line' do
      get :show, params: { order_id: order.prefixed_id, id: tax_line.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(tax_line.prefixed_id)
      expect(json_response['amount']).to eq('1.5')
    end
  end

  it 'does not route create' do
    expect {
      post :create, params: { order_id: order.prefixed_id }, as: :json
    }.to raise_error(ActionController::UrlGenerationError)
  end
end
