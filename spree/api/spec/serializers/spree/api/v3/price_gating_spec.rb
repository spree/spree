require 'spec_helper'

# The prices_hidden gate injects a +hide_prices+ serializer param. These specs
# guard that the cart / order / line-item money surface — and every nested
# record embedded in it — honors it, so a guest can't recover a hidden catalog
# price through the cart, order, or any of their nested serializers.
RSpec.describe 'v3 Store serializer price gating' do
  let(:store) { @default_store || create(:store, default: true) }
  let(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }

  # Derives the currency from the record so nested-serializer examples don't
  # have to build the (expensive) order fixture just to read its currency.
  def serialize(serializer, record = order, hide:)
    currency = record.respond_to?(:currency) ? record.currency : store.default_currency
    JSON.parse(
      serializer.new(record, params: { store: store, currency: currency, hide_prices: hide }).to_h.to_json
    )
  end

  describe Spree::Api::V3::CartSerializer do
    let(:cart) { create(:cart_with_line_items, store: store, line_items_count: 1) }

    it 'nulls totals, store-credit, and nested line-item prices for gated guests' do
      hash = serialize(described_class, cart, hide: true)

      expect(hash['total']).to be_nil
      expect(hash['display_total']).to be_nil
      expect(hash['item_total']).to be_nil
      expect(hash['store_credit_total']).to be_nil
      hash['items'].each do |li|
        expect(li['price']).to be_nil
        expect(li['display_price']).to be_nil
        expect(li['total']).to be_nil
      end
    end

    # A threshold and a shortfall are amounts. A storefront hiding prices from
    # guests must not hand them "$180 short of $500" instead.
    context 'with an order minimum in force' do
      let(:customer) { create(:user) }
      let(:company) { create(:company, store: store) }
      let(:catalog) { create(:catalog, store: store) }

      before do
        create(:company_membership, company: company, customer: customer)
        create(:catalog_assignment, catalog: catalog, assignable: company)
        create(:catalog_order_minimum, catalog: catalog, currency: cart.currency, amount: 500)
        cart.update!(customer: customer, company: company)
        Spree::Current.store = store
        Spree::Current.reset_catalog_memos
      end

      it 'nulls the threshold and shortfall for gated guests' do
        hash = serialize(described_class, cart.reload, hide: true)

        expect(hash['order_minimum']).to be_nil
        expect(hash['order_minimum_shortfall']).to be_nil
        expect(hash['below_order_minimum']).to be_nil
        expect(hash['requirements'].map { |r| r['code'] }).not_to include('order_minimum_not_met')
      end

      it 'states the threshold and shortfall when not gated' do
        hash = serialize(described_class, cart.reload, hide: false)

        expect(hash['order_minimum']).to eq(500.0)
        # What is left to add, so the cart's own items count against it.
        expect(hash['order_minimum_shortfall']).to eq(500.0 - cart.item_total.to_f)
        expect(hash['below_order_minimum']).to be(true)
        expect(hash['requirements'].map { |r| r['code'] }).to include('order_minimum_not_met')
      end
    end

    it 'serializes money fields normally when not gated' do
      hash = serialize(described_class, cart, hide: false)

      expect(hash['total']).to be_present
      expect(hash['items'].first['price']).to be_present
    end

    it 'nulls fee amounts and the fee total for gated guests' do
      create(:fee, cart: cart, order: nil, amount: 7, label: 'Import duty', kind: 'duty')

      hash = serialize(described_class, cart.reload, hide: true)

      expect(hash['fee_total']).to be_nil
      expect(hash['fees'].first['amount']).to be_nil
      expect(hash['fees'].first['display_amount']).to be_nil
    end

    it 'itemizes fees so a storefront can show duties broken out' do
      create(:fee, cart: cart, order: nil, amount: 7, label: 'Import duty', kind: 'duty')

      hash = serialize(described_class, cart.reload, hide: false)

      expect(hash['fee_total']).to be_present
      expect(hash['fees'].first).to include('label' => 'Import duty', 'kind' => 'duty')
      expect(hash['fees'].first['amount']).to be_present
    end
  end

  describe Spree::Api::V3::OrderSerializer do
    it 'nulls totals and store credit for gated guests' do
      hash = serialize(described_class, hide: true)

      expect(hash['total']).to be_nil
      expect(hash['display_total']).to be_nil
      expect(hash['store_credit_total']).to be_nil
      expect(hash['display_store_credit_total']).to be_nil
    end

    it 'serializes totals when not gated' do
      expect(serialize(described_class, hide: false)['total']).to be_present
    end

    it 'keeps fees itemized after placement' do
      create(:fee, order: order, amount: 7, label: 'Import duty', kind: 'duty')

      hash = serialize(described_class, order.reload, hide: false)

      expect(hash['fee_total']).to be_present
      expect(hash['fees'].first).to include('label' => 'Import duty', 'kind' => 'duty')
    end
  end

  # Nested records embedded in a cart/order must honor hide_prices too, so a
  # gated guest can't recover amounts through discounts, payments, fulfillments,
  # or an applied gift card.
  describe 'nested cart/order serializers' do
    describe Spree::Api::V3::PaymentSerializer do
      let(:payment) { create(:payment) }

      it 'nulls the amount for gated guests' do
        hash = serialize(described_class, payment, hide: true)

        expect(hash['amount']).to be_nil
        expect(hash['display_amount']).to be_nil
      end

      it 'serializes the amount when not gated' do
        expect(serialize(described_class, payment, hide: false)['amount']).to be_present
      end
    end

    describe Spree::Api::V3::FulfillmentSerializer do
      let(:shipment) { create(:shipment) }

      it 'nulls every money field for gated guests' do
        hash = serialize(described_class, shipment, hide: true)

        %w[cost display_cost total display_total
           discount_total display_discount_total
           additional_tax_total display_additional_tax_total
           included_tax_total display_included_tax_total
           tax_total display_tax_total].each do |field|
          expect(hash[field]).to be_nil, "expected #{field} to be nil"
        end
      end

      it 'serializes the cost when not gated' do
        expect(serialize(described_class, shipment, hide: false)['cost']).to be_present
      end
    end

    describe Spree::Api::V3::GiftCardSerializer do
      let(:gift_card) { create(:gift_card) }

      it 'nulls every balance field for gated guests' do
        hash = serialize(described_class, gift_card, hide: true)

        %w[amount amount_used amount_authorized amount_remaining
           display_amount display_amount_used display_amount_remaining].each do |field|
          expect(hash[field]).to be_nil, "expected #{field} to be nil"
        end
      end

      it 'serializes balances when not gated' do
        expect(serialize(described_class, gift_card, hide: false)['amount']).to be_present
      end
    end

    describe Spree::Api::V3::AppliedPromotionSerializer do
      # The record is a lightweight applied-promotion presenter responding to
      # the money methods; a struct keeps the gating assertion factory-free.
      let(:applied_promotion) do
        Struct.new(:name, :description, :code, :amount, :display_amount, :promotion, keyword_init: true).new(
          name: 'Promo', description: nil, code: 'SAVE10', amount: '5.0', display_amount: '$5.00', promotion: nil
        )
      end

      it 'nulls the amount for gated guests' do
        hash = serialize(described_class, applied_promotion, hide: true)

        expect(hash['amount']).to be_nil
        expect(hash['display_amount']).to be_nil
      end

      it 'serializes the amount when not gated' do
        expect(serialize(described_class, applied_promotion, hide: false)['amount']).to be_present
      end
    end

    describe Spree::Api::V3::DiscountSerializer do
      let(:discount) do
        Struct.new(:label, :kind, :code, :value, :value_type, :amount, :display_amount,
                   :promotion, :line_item, :fulfillment, keyword_init: true).new(
          label: 'Promo', kind: 'promotion', code: 'SAVE10', value: '10.0', value_type: 'flat',
          amount: '-5.0', display_amount: '-$5.00', promotion: nil, line_item: nil, fulfillment: nil
        )
      end

      it 'nulls the amount for gated guests' do
        hash = serialize(described_class, discount, hide: true)

        expect(hash['amount']).to be_nil
        expect(hash['display_amount']).to be_nil
      end

      it 'serializes the amount when not gated' do
        expect(serialize(described_class, discount, hide: false)['amount']).to be_present
      end
    end
  end
end
