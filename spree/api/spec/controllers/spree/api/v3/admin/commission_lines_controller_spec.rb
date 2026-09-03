require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CommissionLinesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
  let(:order) { create(:order, store: store) }
  let(:line_item) { create(:line_item, order: order) }
  let(:commission_rate) { create(:commission_rate, store: store, name: 'Standard commission') }
  let!(:commission_line) do
    create(:commission_line, order: order, seller: seller, line_item: line_item,
                             commission_rate: commission_rate,
                             amount: 10, tax_amount: 2.1, total: 12.1, currency: 'USD')
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists what the marketplace earned' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('cline_')
      expect(row['seller_name']).to eq('Sparks Audio')
      expect(row).not_to have_key('commission_rate')
    end

    it 'expands the rate that applied' do
      get :index, params: { expand: 'commission_rate' }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['commission_rate']['name']).to eq('Standard commission')
      expect(row['amount']).to eq('10.0')
      expect(row['tax_amount']).to eq('2.1')
      expect(row['total']).to eq('12.1')
      expect(row['display_total']).to eq('$12.10')
    end

    it "hides another marketplace's commission" do
      other_store = create(:store)
      other = create(:commission_line,
                     order: create(:order, store: other_store),
                     seller: create(:seller, store: other_store),
                     line_item: create(:line_item))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'refuses a line from another store' do
      other_store = create(:store)
      other = create(:commission_line,
                     order: create(:order, store: other_store),
                     seller: create(:seller, store: other_store),
                     line_item: create(:line_item))

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # A commission line records something that already happened; correcting one
  # is a reversal, not an edit.
  it 'exposes no write route' do
    expect { patch :update, params: { id: commission_line.prefixed_id }, as: :json }.
      to raise_error(ActionController::UrlGenerationError)
  end
end
