require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StoreCreditsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:customer) { create(:user, email: 'holder@example.com') }
  let!(:store_credit) { create(:store_credit, store: store, customer: customer, amount: 50, currency: 'USD') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns store credits in the current store' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |c| c['id'] }).to include(store_credit.prefixed_id)
    end

    it 'excludes store credits from other stores' do
      other = create(:store_credit, store: create(:store), amount: 25, currency: 'USD')

      subject
      expect(json_response['data'].map { |c| c['id'] }).not_to include(other.prefixed_id)
    end

    it 'exposes the authorized amount and its display string' do
      store_credit.update_columns(amount_authorized: 10)

      subject
      entry = json_response['data'].find { |c| c['id'] == store_credit.prefixed_id }
      expect(entry['amount_authorized']).to eq('10.0')
      expect(entry['display_amount_authorized']).to match(/\$10\.00/)
    end

    it 'reports the originator as a polymorphic shorthand with a prefixed id' do
      gift_card = create(:gift_card, store: store, amount: 50, currency: 'USD')
      store_credit.update!(originator: gift_card)

      subject
      entry = json_response['data'].find { |c| c['id'] == store_credit.prefixed_id }
      expect(entry['originator_type']).to eq('gift_card')
      expect(entry['originator_id']).to eq(gift_card.prefixed_id)
    end

    it 'leaves the originator null for a credit an admin issued by hand' do
      subject
      entry = json_response['data'].find { |c| c['id'] == store_credit.prefixed_id }
      expect(entry['originator_type']).to be_nil
      expect(entry['originator_id']).to be_nil
    end

    describe 'meta.totals' do
      let!(:other_currency) { create(:store_credit, store: store, customer: customer, amount: 30, currency: 'EUR') }

      it 'sums one row per currency over the whole scope' do
        store_credit.update_columns(amount_used: 20, amount_authorized: 5)

        subject
        totals = json_response['meta']['totals']
        usd = totals.find { |row| row['currency'] == 'USD' }

        expect(totals.map { |row| row['currency'] }).to eq(%w[EUR USD])
        expect(usd['amount']).to eq('50.0')
        expect(usd['amount_used']).to eq('20.0')
        expect(usd['amount_authorized']).to eq('5.0')
        expect(usd['amount_remaining']).to eq('25.0')
        expect(usd['display_amount_remaining']).to match(/\$25\.00/)
      end

      it 'follows the active filter rather than the whole store' do
        get :index, params: { q: { currency_eq: 'EUR' } }, as: :json

        totals = json_response['meta']['totals']
        expect(totals.map { |row| row['currency'] }).to eq(['EUR'])
        expect(totals.first['amount']).to eq('30.0')
      end

      it 'counts every match, not only the current page' do
        get :index, params: { limit: 1 }, as: :json

        expect(json_response['data'].size).to eq(1)
        expect(json_response['meta']['totals'].size).to eq(2)
      end

      it 'is an empty list when nothing matches' do
        get :index, params: { q: { currency_eq: 'GBP' } }, as: :json

        expect(json_response['meta']['totals']).to eq([])
      end
    end

    describe 'filters' do
      let!(:spent) do
        create(:store_credit, store: store, customer: customer, amount: 40, currency: 'USD').
          tap { |credit| credit.update_columns(amount_used: 40) }
      end

      it 'narrows to credits with money left via the outstanding scope' do
        get :index, params: { q: { outstanding: 'true' } }, as: :json

        ids = json_response['data'].map { |c| c['id'] }
        expect(ids).to include(store_credit.prefixed_id)
        expect(ids).not_to include(spent.prefixed_id)
      end

      it 'narrows to spent credits when outstanding is false' do
        get :index, params: { q: { outstanding: 'false' } }, as: :json

        ids = json_response['data'].map { |c| c['id'] }
        expect(ids).to include(spent.prefixed_id)
        expect(ids).not_to include(store_credit.prefixed_id)
      end

      it 'filters by the customer email through the association' do
        elsewhere = create(:store_credit, store: store, customer: create(:user, email: 'someone@else.test'), amount: 5)

        get :index, params: { q: { customer_email_cont: 'holder@' } }, as: :json

        ids = json_response['data'].map { |c| c['id'] }
        expect(ids).to include(store_credit.prefixed_id)
        expect(ids).not_to include(elsewhere.prefixed_id)
      end

      it 'filters by whether a gift card issued the credit' do
        gift_card = create(:gift_card, store: store, amount: 50, currency: 'USD')
        from_card = create(:store_credit, store: store, customer: customer, amount: 15, originator: gift_card)

        get :index, params: { q: { from_gift_card: 'true' } }, as: :json

        expect(json_response['data'].map { |c| c['id'] }).to eq([from_card.prefixed_id])
      end

      it 'filters by the memo' do
        tagged = create(:store_credit, store: store, customer: customer, amount: 5, memo: 'goodwill for late delivery')

        get :index, params: { q: { memo_cont: 'goodwill' } }, as: :json

        expect(json_response['data'].map { |c| c['id'] }).to eq([tagged.prefixed_id])
      end
    end
  end

  describe 'GET #show' do
    it 'returns the credit' do
      get :show, params: { id: store_credit.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(store_credit.prefixed_id)
      expect(json_response['memo']).to eq(store_credit.memo)
    end

    it '404s for a credit in another store' do
      other = create(:store_credit, store: create(:store), amount: 25)

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'write actions' do
    it 'has no create, update or destroy route' do
      expect { post :create, as: :json }.to raise_error(ActionController::UrlGenerationError)
    end
  end
end
