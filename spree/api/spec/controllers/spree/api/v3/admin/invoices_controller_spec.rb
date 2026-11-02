require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::InvoicesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:order) { create(:completed_order_with_totals, store: store) }
  let!(:invoice) { create(:invoice, order: order) }
  let!(:credit_note) { create(:invoice, :credit_note, order: order, original_invoice: invoice) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store\'s invoices and credit notes' do
      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).to contain_exactly(invoice.prefixed_id, credit_note.prefixed_id)
    end

    it 'filters by kind' do
      get :index, params: { q: { kind_eq: 'credit_note' } }, as: :json

      expect(json_response['data'].map { |row| row['id'] }).to eq([credit_note.prefixed_id])
    end

    it 'does not leak another store' do
      other = create(:invoice, order: create(:completed_order_with_totals, store: create(:store)))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end

    context 'with a key that may read orders but not payouts' do
      let(:caller_key) { create(:api_key, :secret, store: store, scopes: ['read_orders']) }
      let!(:commission) { create(:invoice, :commission, seller_payout: create(:seller_payout, store: store)) }

      before do
        request.headers['Authorization'] = nil
        request.headers['x-spree-api-key'] = caller_key.plaintext_token
      end

      it 'leaves commission invoices out of the list and refuses to open one' do
        get :index, as: :json
        expect(json_response['data'].map { |row| row['id'] }).not_to include(commission.prefixed_id)

        get :show, params: { id: commission.prefixed_id }, as: :json
        expect(response.status).to be_in([403, 404])
      end
    end

    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { expand: 'order' }, as: :json }
    end
  end

  describe 'POST #resend' do
    it 'asks for the invoice to be emailed again', :events do
      allow(Spree::Events).to receive(:publish).and_call_original

      post :resend, params: { id: invoice.prefixed_id }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(Spree::Events).to have_received(:publish).with('invoice.delivery_requested', any_args)
    end
  end
end
