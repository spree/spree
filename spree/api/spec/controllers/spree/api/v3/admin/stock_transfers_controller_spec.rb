require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StockTransfersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:source_location) { create(:stock_location_with_items, name: 'Source') }
  let!(:destination_location) { create(:stock_location, name: 'Destination') }
  let(:variant) { create(:variant) }

  before do
    request.headers.merge!(headers)
    source_location.stock_level_or_create(variant).update!(count_on_hand: 50)
    destination_location.stock_level_or_create(variant)
  end

  describe 'GET #index' do
    let!(:transfer) do
      Spree::StockTransfer.new.tap { |t| t.transfer(source_location, destination_location, variant => 5) }
    end

    it 'returns stock transfers' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |t| t['id'] }).to include(transfer.prefixed_id)
    end

    # The dashboard's search box sends this one predicate for both columns, so
    # a whitelist that covers only `number` would silently return every row.
    context 'searching by number or reference' do
      let!(:referenced) do
        Spree::StockTransfer.new(reference: 'PO-4471').tap do |t|
          t.transfer(source_location, destination_location, variant => 1)
        end
      end

      it 'matches on the reference' do
        get :index, params: { q: { number_or_reference_cont: 'PO-4471' } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |t| t['id'] }
        expect(ids).to eq([referenced.prefixed_id])
      end

      it 'matches on the number' do
        get :index, params: { q: { number_or_reference_cont: transfer.number } }, as: :json

        expect(response).to have_http_status(:ok)
        ids = json_response['data'].map { |t| t['id'] }
        expect(ids).to eq([transfer.prefixed_id])
      end
    end
  end

  describe 'POST #create' do
    let(:base_params) do
      {
        source_location_id: source_location.prefixed_id,
        destination_location_id: destination_location.prefixed_id,
        variants: [{ variant_id: variant.prefixed_id, quantity: 5 }]
      }
    end

    it 'transfers stock between locations' do
      expect { post :create, params: base_params, as: :json }.
        to change(Spree::StockTransfer, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(source_location.stock_level(variant).reload.count_on_hand).to eq(45)
      expect(destination_location.stock_level(variant).reload.count_on_hand).to eq(5)
    end

    it 'receives from external seller when source is omitted' do
      post :create, params: base_params.except(:source_location_id), as: :json

      expect(response).to have_http_status(:created)
      expect(destination_location.stock_level(variant).reload.count_on_hand).to eq(5)
    end

    it 'returns 422 when variants is empty' do
      post :create, params: base_params.merge(variants: []), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('invalid_variants')
    end

    it 'returns 404 when destination location is unknown' do
      post :create, params: base_params.merge(destination_location_id: 'sloc_unknown'), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "drops variants belonging to another store and surfaces invalid_variants" do
      foreign_variant = create(:product, store: create(:store)).default_variant

      expect do
        post :create, params: base_params.merge(
          variants: [{ variant_id: foreign_variant.prefixed_id, quantity: 5 }]
        ), as: :json
      end.not_to change(Spree::StockTransfer, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('invalid_variants')
    end
  end
end
