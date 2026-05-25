require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PriceListsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:price_list) { create(:price_list, store: store, name: 'Wholesale') }

  before { request.headers.merge!(headers) }

  describe 'POST #create — one-shot creation' do
    let(:customer_group) { create(:customer_group, store: store) }

    context 'admin UI shape (product_ids + rules)' do
      let(:product1) { create(:product, stores: [store]) }
      let(:product2) { create(:product, stores: [store]) }

      it 'persists metadata, products, and rules in one request' do
        post :create,
             params: {
               name: 'EU wholesale',
               description: 'B2B verified customers',
               match_policy: 'all',
               product_ids: [product1.prefixed_id, product2.prefixed_id],
               rules: [
                 {
                   type: 'customer_group_rule',
                   preferences: { customer_group_ids: [customer_group.prefixed_id] }
                 },
                 { type: 'volume_rule', preferences: { min_quantity: 10 } }
               ]
             },
             as: :json

        expect(response).to have_http_status(:created)
        list = Spree::PriceList.for_store(store).find_by!(name: 'EU wholesale')
        expect(list.match_policy).to eq('all')
        expect(list.products).to contain_exactly(product1, product2)
        expect(list.price_rules.length).to eq(2)
        cg_rule = list.price_rules.find { |r| r.is_a?(Spree::PriceRules::CustomerGroupRule) }
        volume_rule = list.price_rules.find { |r| r.is_a?(Spree::PriceRules::VolumeRule) }
        expect(cg_rule.preferred_customer_group_ids).to contain_exactly(customer_group.id)
        expect(volume_rule.preferred_min_quantity).to eq(10)
      end
    end

    context 'server-to-server shape (rules + prices, no product_ids)' do
      # The natural API shape when the caller already knows per-variant
      # prices. Variants in `prices` implicitly become part of the list
      # via the unique-key upsert — no separate `product_ids` round trip.
      let(:product) { create(:product, stores: [store]) }
      let(:variant_a) { product.master }
      let(:variant_b) { create(:variant, product: product) }

      it 'persists metadata, rules, and prices in one request' do
        post :create,
             params: {
               name: 'EU wholesale',
               match_policy: 'all',
               rules: [{ type: 'volume_rule', preferences: { min_quantity: 10 } }],
               prices: [
                 {
                   variant_id: variant_a.prefixed_id,
                   currency: 'USD',
                   amount: '19.99',
                   compare_at_amount: '24.99'
                 },
                 {
                   variant_id: variant_b.prefixed_id,
                   currency: 'USD',
                   amount: '21.99'
                 }
               ]
             },
             as: :json

        expect(response).to have_http_status(:created)
        list = Spree::PriceList.for_store(store).find_by!(name: 'EU wholesale')

        rows = list.prices.where(currency: 'USD').to_a
        a_row = rows.find { |r| r.variant_id == variant_a.id }
        b_row = rows.find { |r| r.variant_id == variant_b.id }
        expect(a_row.amount).to eq(BigDecimal('19.99'))
        expect(a_row.compare_at_amount).to eq(BigDecimal('24.99'))
        expect(b_row.amount).to eq(BigDecimal('21.99'))

        expect(list.price_rules.length).to eq(1)
        expect(list.price_rules.first).to be_a(Spree::PriceRules::VolumeRule)
      end
    end
  end

  describe 'PATCH #update — prices nullability contract' do
    let(:product) { create(:product, stores: [store]) }
    let(:variant) { product.master }
    # Seed an existing override so we can prove it survives or gets
    # cleared depending on the request shape.
    let!(:price) do
      price_list.prices.create!(
        variant: variant,
        currency: 'USD',
        amount: BigDecimal('42.00'),
        compare_at_amount: BigDecimal('50.00')
      )
    end

    context 'when the prices key is omitted entirely' do
      # The naive bug is: `prices=` runs unconditionally and treats a
      # missing key the same as `[]`, blanking everything out. Guard
      # against it by leaving the rest of the update alone.
      it 'leaves existing overrides untouched' do
        patch :update, params: { id: price_list.prefixed_id, name: 'Renamed' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(price_list.reload.name).to eq('Renamed')
        expect(price.reload.amount).to eq(BigDecimal('42.00'))
        expect(price.compare_at_amount).to eq(BigDecimal('50.00'))
      end
    end

    context 'when prices is explicitly an empty array' do
      # The flip side: an empty array is a clear-intent signal. The
      # spreadsheet UI uses this when the user wipes every cell and saves.
      it 'clears amount and compare_at_amount on every existing override' do
        patch :update, params: { id: price_list.prefixed_id, prices: [] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(price.reload.amount).to be_nil
        expect(price.compare_at_amount).to be_nil
      end

      it 'keeps the price rows themselves' do
        # The unique index on (variant_id, currency, price_list_id) means
        # we can't safely hard-delete and re-create the row on the next
        # save — so the clear-intent path nulls amounts in place.
        expect {
          patch :update, params: { id: price_list.prefixed_id, prices: [] }, as: :json
        }.not_to change { price_list.prices.count }
      end
    end

    context 'when prices carries an upsert row' do
      it 'updates the listed row only' do
        patch :update,
              params: {
                id: price_list.prefixed_id,
                prices: [{
                  id: price.prefixed_id,
                  variant_id: variant.prefixed_id,
                  currency: 'USD',
                  amount: '19.99',
                  compare_at_amount: '24.99'
                }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(price.reload.amount).to eq(BigDecimal('19.99'))
        expect(price.compare_at_amount).to eq(BigDecimal('24.99'))
      end

      it 'ignores rows whose id is not in this list' do
        other_list = create(:price_list, store: store)
        foreign_price = other_list.prices.create!(
          variant: variant, currency: 'USD', amount: BigDecimal('1.00')
        )

        patch :update,
              params: {
                id: price_list.prefixed_id,
                prices: [{ id: foreign_price.prefixed_id, amount: '9.99' }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        # The foreign row was not in this list's `prices` scope, so the
        # bulk upsert silently skipped it rather than reaching across.
        expect(foreign_price.reload.amount).to eq(BigDecimal('1.00'))
      end
    end
  end
end
