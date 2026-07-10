require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PriceListsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:price_list) { create(:price_list, store: store, name: 'Wholesale') }

  before { request.headers.merge!(headers) }

  describe 'POST #create — one-shot creation' do
    let(:customer_group) { create(:customer_group, store: store) }

    context 'admin UI shape (product_ids + rules)' do
      let(:product1) { create(:product) }
      let(:product2) { create(:product) }

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
        # Preferences are normalized to string-coerced raw IDs by the
        # rule's `parse_on_set` decoder — prefixed `cg_…` IDs come in
        # off the wire and land as `customer_group.id.to_s` in storage.
        expect(cg_rule.preferred_customer_group_ids).to contain_exactly(customer_group.id.to_s)
        expect(volume_rule.preferred_min_quantity).to eq(10)
      end
    end

    context 'server-to-server shape (rules + prices, no product_ids)' do
      # The natural API shape when the caller already knows per-variant
      # prices. Variants in `prices` implicitly become part of the list
      # via the unique-key upsert — no separate `product_ids` round trip.
      let(:product) { create(:product) }
      let(:variant_a) { product.default_variant }
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

    context 'cross-store IDOR — membership in another store' do
      let(:other_store) { create(:store) }
      let(:foreign_product) { create(:product, store: other_store) }
      let(:foreign_variant) { foreign_product.default_variant }

      it 'ignores another store\'s product in product_ids' do
        post :create,
             params: { name: 'Sneaky list', match_policy: 'all', product_ids: [foreign_product.prefixed_id] },
             as: :json

        expect(response).to have_http_status(:created)
        list = Spree::PriceList.for_store(store).find_by!(name: 'Sneaky list')
        expect(list.products).to be_empty
      end

      it 'ignores another store\'s variant in nested prices' do
        post :create,
             params: {
               name: 'Sneaky price list',
               match_policy: 'all',
               prices: [{ variant_id: foreign_variant.prefixed_id, currency: 'USD', amount: '0.01' }]
             },
             as: :json

        expect(response).to have_http_status(:created)
        list = Spree::PriceList.for_store(store).find_by!(name: 'Sneaky price list')
        expect(list.prices.where(variant_id: foreign_variant.id)).to be_empty
      end
    end
  end

  describe 'POST #create — per rule type' do
    # Covers every registered subclass in `Spree.pricing.rules`. Each
    # case asserts the rule persists as the right STI subclass, that
    # wire preferences land in the model with the expected coercion
    # (prefixed IDs decoded, scalars typed), and that the API embed is
    # present where applicable.
    #
    # `list_name` is unique per context to keep `find_by!` deterministic
    # under random spec ordering — the suite has many "EU wholesale"
    # callsites and `let!(:price_list)` already seeds another list.
    let(:created_list) { Spree::PriceList.for_store(store).find_by!(name: list_name) }
    let(:base_params) { { name: list_name, match_policy: 'all' } }

    context 'volume_rule' do
      let(:list_name) { 'Volume list' }

      it 'persists min_quantity / max_quantity as integers' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'volume_rule', preferences: { min_quantity: 5, max_quantity: 25 } }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        rule = created_list.price_rules.first
        expect(rule).to be_a(Spree::PriceRules::VolumeRule)
        expect(rule.preferred_min_quantity).to eq(5)
        expect(rule.preferred_max_quantity).to eq(25)
      end

      it 'accepts a nil max_quantity (unbounded ceiling)' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'volume_rule', preferences: { min_quantity: 3, max_quantity: nil } }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        rule = created_list.price_rules.first
        expect(rule.preferred_min_quantity).to eq(3)
        expect(rule.preferred_max_quantity).to be_nil
      end
    end

    # NOTE: market_rule wire-decoding is covered by the model spec —
    # `Spree::PriceRules::MarketRule#preferred_market_ids=` (see
    # `spec/models/spree/price_rules/market_rule_spec.rb`). Creating
    # markets through the factory in this controller suite leaks
    # transactional state via the factory's `after(:build)` callback
    # (Zone / ShippingMethod), so the controller-level coverage uses
    # customer_group_rule instead.

    context 'customer_group_rule' do
      let(:list_name) { 'Customer group list' }
      let(:customer_group) { create(:customer_group, store: store) }
      let(:other_group) { create(:customer_group, store: store) }

      it 'decodes prefixed customer-group IDs to raw IDs in storage' do
        post :create,
             params: base_params.merge(
               rules: [{
                 type: 'customer_group_rule',
                 preferences: { customer_group_ids: [customer_group.prefixed_id, other_group.prefixed_id] }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        rule = created_list.price_rules.first
        expect(rule).to be_a(Spree::PriceRules::CustomerGroupRule)
        expect(rule.preferred_customer_group_ids).to contain_exactly(customer_group.id.to_s, other_group.id.to_s)
        expect(rule.customer_groups).to contain_exactly(customer_group, other_group)
      end

      it 'returns 404 for an unknown customer-group ID' do
        post :create,
             params: base_params.merge(
               rules: [{
                 type: 'customer_group_rule',
                 preferences: { customer_group_ids: ['cg_doesnotexist'] }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'user_rule' do
      # Wire shorthand is `user_rule` (legacy preference column name);
      # the SPA labels it "Customer rule".
      let(:list_name) { 'User list' }
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }

      it 'decodes prefixed user IDs to raw IDs in storage' do
        post :create,
             params: base_params.merge(
               rules: [{
                 type: 'user_rule',
                 preferences: { user_ids: [user.prefixed_id, other_user.prefixed_id] }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        rule = created_list.price_rules.first
        expect(rule).to be_a(Spree::PriceRules::UserRule)
        expect(rule.preferred_user_ids).to contain_exactly(user.id.to_s, other_user.id.to_s)
        expect(rule.users).to contain_exactly(user, other_user)
      end

      it 'returns 404 for an unknown user ID' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'user_rule', preferences: { user_ids: ['cus_doesnotexist'] } }]
             ),
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'duplicate rule types in a single payload' do
      let(:list_name) { 'Dup rule list' }

      it 'rejects two rules of the same type on one list' do
        post :create,
             params: base_params.merge(
               rules: [
                 { type: 'volume_rule', preferences: { min_quantity: 1 } },
                 { type: 'volume_rule', preferences: { min_quantity: 2 } }
               ]
             ),
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH #update — rule reconciliation per rule type' do
    # The flat payload contract: existing rules update in place when
    # matched by id; rules omitted from the payload get destroyed.
    let(:customer_group) { create(:customer_group, store: store) }

    it 'updates a volume_rule in place when matched by id' do
      rule = price_list.price_rules.create!(
        type: 'Spree::PriceRules::VolumeRule', preferences: { min_quantity: 1 }
      )

      patch :update,
            params: {
              id: price_list.prefixed_id,
              rules: [{ id: rule.prefixed_id, type: 'volume_rule', preferences: { min_quantity: 50 } }]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(rule.reload.preferred_min_quantity).to eq(50)
    end

    it 'replaces customer_group_ids on an existing customer_group_rule' do
      rule = price_list.price_rules.create!(type: 'Spree::PriceRules::CustomerGroupRule')
      rule.preferred_customer_group_ids = [customer_group.id]
      rule.save!
      other_group = create(:customer_group, store: store)

      patch :update,
            params: {
              id: price_list.prefixed_id,
              rules: [{
                id: rule.prefixed_id,
                type: 'customer_group_rule',
                preferences: { customer_group_ids: [other_group.prefixed_id] }
              }]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(rule.reload.preferred_customer_group_ids).to contain_exactly(other_group.id.to_s)
    end

    it 'destroys rules omitted from the payload' do
      kept = price_list.price_rules.create!(
        type: 'Spree::PriceRules::VolumeRule', preferences: { min_quantity: 1 }
      )
      removed = price_list.price_rules.create!(type: 'Spree::PriceRules::MarketRule')

      patch :update,
            params: {
              id: price_list.prefixed_id,
              rules: [{ id: kept.prefixed_id, type: 'volume_rule' }]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(price_list.price_rules.pluck(:id)).to eq([kept.id])
      expect(Spree::PriceRule.find_by(id: removed.id)).to be_nil
    end

    it 'destroys all rules when given an empty array' do
      price_list.price_rules.create!(
        type: 'Spree::PriceRules::VolumeRule', preferences: { min_quantity: 1 }
      )

      patch :update,
            params: { id: price_list.prefixed_id, rules: [] },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(price_list.reload.price_rules).to be_empty
    end

    it 'adds a new rule alongside an existing one in a single PATCH' do
      existing = price_list.price_rules.create!(
        type: 'Spree::PriceRules::VolumeRule', preferences: { min_quantity: 1 }
      )

      patch :update,
            params: {
              id: price_list.prefixed_id,
              rules: [
                { id: existing.prefixed_id, type: 'volume_rule', preferences: { min_quantity: 1 } },
                {
                  type: 'customer_group_rule',
                  preferences: { customer_group_ids: [customer_group.prefixed_id] }
                }
              ]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      rules = price_list.reload.price_rules
      expect(rules.length).to eq(2)
      cg_rule = rules.find { |r| r.is_a?(Spree::PriceRules::CustomerGroupRule) }
      expect(cg_rule.preferred_customer_group_ids).to contain_exactly(customer_group.id.to_s)
    end

    it 'silently drops a rule with an unknown type' do
      patch :update,
            params: {
              id: price_list.prefixed_id,
              rules: [
                { type: 'volume_rule', preferences: { min_quantity: 2 } },
                { type: 'NotARealRule' }
              ]
            },
            as: :json

      expect(response).to have_http_status(:ok)
      rules = price_list.reload.price_rules
      expect(rules.length).to eq(1)
      expect(rules.first).to be_a(Spree::PriceRules::VolumeRule)
    end
  end

  describe 'PATCH #update — prices nullability contract' do
    let(:product) { create(:product) }
    let(:variant) { product.default_variant }
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
