require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CommissionLinesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:vendor) { create(:vendor, :approved, store: store, name: 'Sparks Audio') }
  let(:order) { create(:order, store: store) }
  let(:line_item) { create(:line_item, order: order) }
  let!(:commission_line) do
    create(:commission_line, order: order, vendor: vendor, line_item: line_item,
                             amount: 10, tax_amount: 2.1, total: 12.1, currency: 'USD')
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists what the marketplace earned' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('comln_')
      expect(row['vendor_name']).to eq('Sparks Audio')
      expect(row['amount']).to eq('10.0')
      expect(row['tax_amount']).to eq('2.1')
      expect(row['total']).to eq('12.1')
      expect(row['display_total']).to eq('$12.10')
    end

    it "hides another marketplace's commission" do
      other_store = create(:store)
      other = create(:commission_line,
                     order: create(:order, store: other_store),
                     vendor: create(:vendor, store: other_store),
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
                     vendor: create(:vendor, store: other_store),
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
