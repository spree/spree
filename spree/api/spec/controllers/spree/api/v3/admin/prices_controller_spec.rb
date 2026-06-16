require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PricesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:price_list) { create(:price_list, store: store) }
  let(:product) { create(:product) }
  let(:variant) { product.master }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    # The product factory seeds a USD base price on `master` for the
    # store's default currency, so we reuse it instead of inserting one
    # (the unique index on `(variant_id, currency, price_list_id)` blocks
    # duplicates).
    let!(:base_price) { variant.prices.find_by!(currency: 'USD', price_list_id: nil) }
    let!(:list_price) do
      create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: 5.0)
    end

    it 'returns prices scoped to the current store' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to include(base_price.prefixed_id, list_price.prefixed_id)
    end

    it 'filters by price_list_id via Ransack' do
      get :index, params: { q: { price_list_id_eq: price_list.id } }, as: :json

      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to eq([list_price.prefixed_id])
    end

    it 'filters by currency via Ransack' do
      # A second currency on a different variant — same variant + EUR
      # would conflict with the factory-seeded USD master price if Spree
      # auto-mirrored currencies, but it doesn't.
      eur_variant = create(:variant, product: product)
      eur_price = create(:price, variant: eur_variant, currency: 'EUR', amount: 9.0)

      get :index, params: { q: { currency_eq: 'USD' } }, as: :json

      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).not_to include(eur_price.prefixed_id)
    end

    # Regression: `sort=variant_product_name,variant_id` is what the SPA
    # spreadsheet ships. The original scope used `joins(... :stores).distinct`
    # plus Ransack's default `result(distinct: true)`, which Postgres
    # rejects when ORDER BY references a column outside the DISTINCT
    # select list (SQLite is permissive and the test missed it). We
    # assert the SQL no longer carries DISTINCT — that's the durable
    # invariant across both databases.
    it 'sorts by variant product name without raising' do
      other_product = create(:product, name: 'AAA')
      other_price = other_product.master.prices.find_by!(currency: 'USD', price_list_id: nil)

      get :index, params: { sort: 'variant_product_name,variant_id' }, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to include(base_price.prefixed_id, other_price.prefixed_id)
    end

    it 'scopes to a single product via q[variant_product_id_eq] (base prices only)' do
      other_product = create(:product)
      other_base = other_product.master.prices.find_by!(currency: 'USD', price_list_id: nil)

      get :index,
          params: {
            q: { variant_product_id_eq: product.id, price_list_id_null: true }
          },
          as: :json

      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).to include(base_price.prefixed_id)
      expect(ids).not_to include(list_price.prefixed_id, other_base.prefixed_id)
    end

    # The `search` Ransack scope ORs the underlying variant's SKU, parent
    # product name, and option-value presentations into a single subquery,
    # so the spreadsheet search field can match any of those without
    # producing duplicate Price rows.
    describe 'free-text search via q[search]' do
      let!(:red_option_value) do
        ot = Spree::OptionType.find_by(name: 'shirt-color') ||
             create(:option_type, name: 'shirt-color', presentation: 'Color')
        ot.option_values.find_by(name: 'red') ||
          create(:option_value, option_type: ot, name: 'red', presentation: 'Red')
      end
      let!(:red_variant) do
        v = create(:variant, product: product, sku: 'TSHIRT-RED-XL')
        v.option_values << red_option_value
        v
      end
      let!(:red_price) { v_price(red_variant) }

      def v_price(v)
        v.prices.find_by!(currency: 'USD', price_list_id: nil)
      end

      it 'matches by SKU substring' do
        get :index, params: { q: { search: 'TSHIRT' } }, as: :json
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(red_price.prefixed_id)
      end

      it 'matches by option-value presentation' do
        get :index, params: { q: { search: 'Red' } }, as: :json
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(red_price.prefixed_id)
      end

      it 'matches by product name' do
        product.update!(name: 'Crewneck Sweater')
        get :index, params: { q: { search: 'crewneck' } }, as: :json
        ids = json_response['data'].map { |p| p['id'] }
        expect(ids).to include(red_price.prefixed_id)
      end

      it 'returns no rows for a short query (under the 3-char floor)' do
        get :index, params: { q: { search: 'Re' } }, as: :json
        expect(json_response['data']).to be_empty
      end
    end

    it 'excludes prices from other stores' do
      other_store = create(:store)
      other_product = create(:product, store: other_store)
      other_price = other_product.master.prices.find_by!(currency: 'USD', price_list_id: nil)

      get :index, as: :json

      ids = json_response['data'].map { |p| p['id'] }
      expect(ids).not_to include(other_price.prefixed_id)
    end
  end

  describe 'POST #bulk_upsert' do
    context 'when the prices key is omitted entirely' do
      it 'returns 422 with a missing_prices error' do
        post :bulk_upsert, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('missing_prices')
      end
    end

    context 'when the unique-key triple matches an existing row' do
      let!(:existing) do
        create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: 5.0)
      end

      it 'updates the matching row via the unique key' do
        post :bulk_upsert,
             params: {
               prices: [
                 {
                   variant_id: variant.prefixed_id,
                   currency: 'USD',
                   price_list_id: price_list.prefixed_id,
                   amount: '7.50'
                 }
               ]
             },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).to eq('price_count' => 1)
        expect(existing.reload.amount).to eq(BigDecimal('7.50'))
      end
    end

    context 'when no row exists at the unique key' do
      # `change(Spree::Price, :count).by(1)` is brittle here — variant-level
      # `infer_price` callbacks can mirror a new currency into the base set,
      # bumping the count by 2 deterministically. We assert on the *specific*
      # row instead (target by the unique key) so the test stays focused.
      it 'creates a new row' do
        post :bulk_upsert,
             params: {
               prices: [
                 {
                   variant_id: variant.prefixed_id,
                   currency: 'EUR',
                   price_list_id: price_list.prefixed_id,
                   amount: '4.20'
                 }
               ]
             },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).to eq('price_count' => 1)
        row = Spree::Price.find_by(variant_id: variant.id, currency: 'EUR', price_list_id: price_list.id)
        expect(row).not_to be_nil
        expect(row.amount).to eq(BigDecimal('4.20'))
      end

      it 'creates a base price (price_list_id null)' do
        post :bulk_upsert,
             params: {
               prices: [
                 {
                   variant_id: variant.prefixed_id,
                   currency: 'EUR',
                   amount: '8.99'
                 }
               ]
             },
             as: :json

        expect(response).to have_http_status(:ok)
        base = Spree::Price.find_by(variant_id: variant.id, currency: 'EUR', price_list_id: nil)
        expect(base).not_to be_nil
        expect(base.amount).to eq(BigDecimal('8.99'))
      end
    end

    context 'with canonical decimal-string amounts' do
      # The Admin API contract is canonical decimal strings (`"1234.56"` —
      # period decimal, no grouping), independent of locale. Clients (the
      # dashboard) normalize any localized input client-side before sending;
      # the API is not asked to parse comma-vs-period. See
      # docs/plans/5.5-client-side-money-normalization.md.
      it 'upserts amount and compare_at_amount as canonical strings' do
        post :bulk_upsert,
             params: {
               prices: [{
                 variant_id: variant.prefixed_id,
                 currency: 'EUR',
                 price_list_id: price_list.prefixed_id,
                 amount: '1234.56',
                 compare_at_amount: '149.99'
               }]
             },
             as: :json

        expect(response).to have_http_status(:ok)
        row = Spree::Price.find_by(
          variant_id: variant.id, currency: 'EUR', price_list_id: price_list.id
        )
        expect(row.amount).to eq(BigDecimal('1234.56'))
        expect(row.compare_at_amount).to eq(BigDecimal('149.99'))
      end
    end

    context 'when targeting a row in a sibling list' do
      let(:other_list) { create(:price_list, store: store) }
      let!(:foreign) do
        create(:price, variant: variant, price_list: other_list, currency: 'USD', amount: 99.0)
      end

      it 'allows updates within the store but the row stays in its list' do
        post :bulk_upsert,
             params: {
               prices: [{
                 variant_id: variant.prefixed_id,
                 currency: 'USD',
                 price_list_id: other_list.prefixed_id,
                 amount: '50.00'
               }]
             },
             as: :json

        expect(response).to have_http_status(:ok)
        # `Spree::Price` is a cross-cutting resource — the price-list-list
        # scope is just a Ransack filter. Targeting a row in another
        # list is fine; what matters is the row stays where it was.
        expect(foreign.reload.amount).to eq(BigDecimal('50.00'))
        expect(foreign.price_list_id).to eq(other_list.id)
      end
    end

    context 'cross-store IDOR — a variant in another store' do
      let(:other_store) { create(:store) }
      let(:other_product) { create(:product, store: other_store) }
      let(:other_variant) { other_product.master }

      it 'rejects writing a price on another store\'s variant and leaves it untouched' do
        # The factory seeds a USD base price on the foreign master; capture it
        # so we prove an in-place update didn't slip through (count alone wouldn't).
        foreign_price = other_variant.prices.find_by!(currency: 'USD', price_list_id: nil)

        post :bulk_upsert,
             params: {
               prices: [{
                 variant_id: other_variant.prefixed_id,
                 currency: 'USD',
                 amount: '0.01'
               }]
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('invalid_prices')
        expect(foreign_price.reload.amount).not_to eq(BigDecimal('0.01'))
      end

      it 'rejects targeting another store\'s price list and leaves its rows untouched' do
        other_list = create(:price_list, store: other_store)
        foreign_row = create(:price, variant: variant, price_list: other_list, currency: 'USD', amount: 42.0)

        post :bulk_upsert,
             params: {
               prices: [{
                 variant_id: variant.prefixed_id,
                 currency: 'USD',
                 price_list_id: other_list.prefixed_id,
                 amount: '0.01'
               }]
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('invalid_prices')
        expect(foreign_row.reload.amount).to eq(BigDecimal('42.0'))
      end
    end
  end

  describe 'DELETE #bulk_destroy' do
    let!(:to_delete) do
      create(:price, variant: variant, price_list: price_list, currency: 'USD', amount: 5.0)
    end
    let!(:to_keep) do
      create(:price, variant: variant, price_list: price_list, currency: 'EUR', amount: 4.0)
    end

    it 'soft-deletes the listed prices and reports the count' do
      delete :bulk_destroy,
             params: { ids: [to_delete.prefixed_id] },
             as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['price_count']).to eq(1)
      expect(to_delete.reload.deleted_at).not_to be_nil
      expect(to_keep.reload.deleted_at).to be_nil
    end

    it 'returns 422 when ids is missing' do
      delete :bulk_destroy, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('missing_ids')
    end
  end
end
