# frozen_string_literal: true

require 'spec_helper'

# The money contract (docs/plans/6.0-money-correctness.md): every money amount
# is a decimal string with exactly its currency's decimals, unit prices keep up
# to four, rates are decimal strings, and nothing money-shaped is a JSON number.
RSpec.describe 'API v3 money contract' do
  let(:store) { @default_store }

  def money_name = /(\A|_)(amount|price|total|cost|fee|payout|discount|tax|revenue|balance|refund|credit|minimum|earned|payable|paid|pending|subtotal)(\z|_)/
  def rate_name = /(\A|_)(rate|percent|percentage)\z/
  def not_money = /(\A|_)(id|ids|count|quantity|status|kind|type|code|label|name|at|unit|method|methods|provider|currency)\z|\Adisplay_|\Atotal_(quantity|units|cartons|on_hand)\z|delivery_count/
  def unit_price_keys = %w[price compare_at_amount cost_price unit_cost catalog_price original_price new_variant_price]

  # Walks a payload and yields every money- or rate-named scalar with the
  # currency of the hash it sits in.
  def each_decimal(node, currency = nil, path = [], &block)
    case node
    when Hash
      currency = node['currency'] if node['currency'].is_a?(String)
      node.each do |key, value|
        next if key.match?(not_money)

        if value.is_a?(Hash) || value.is_a?(Array)
          each_decimal(value, currency, path + [key], &block)
        elsif value && (key.match?(money_name) || key.match?(rate_name))
          yield(key, value, currency, path + [key])
        end
      end
    when Array
      node.each_with_index { |item, index| each_decimal(item, currency, path + [index], &block) }
    end
  end

  def expect_contract(payload, prices: false)
    checked = 0
    each_decimal(payload) do |key, value, currency, path|
      checked += 1
      expect(value).to be_a(String), "#{path.join('.')} is #{value.inspect}, not a decimal string"
      expect(value).to match(/\A-?\d+(\.\d+)?\z/), "#{path.join('.')} is #{value.inspect}"
      next if key.match?(rate_name) || currency.nil?

      places = value.include?('.') ? value.split('.').last.length : 0
      exponent = Spree::Money::Rounding.precision(currency)
      if unit_price_keys.include?(key) || (key == 'amount' && (prices || path.include?('price')))
        expect(places).to be_between(exponent, [exponent, 4].max), "#{path.join('.')} #{value} (#{currency})"
      else
        expect(places).to eq(exponent), "#{path.join('.')} #{value} has #{places} decimals, #{currency} has #{exponent}"
      end
    end
    expect(checked).to be_positive
  end

  def serialize(serializer, record, **params)
    JSON.parse(serializer.new(record, params: { store: store, currency: record.try(:currency) || 'USD', **params }).to_json)
  end

  %w[USD KWD JPY].each do |currency|
    context "in #{currency}" do
      let(:order) do
        create(:completed_order_with_totals, store: store).tap do |order|
          order.update_columns(currency: currency)
          order.line_items.update_all(currency: currency)
        end.reload
      end

      it 'writes order totals and line items to the currency' do
        expect_contract(serialize(Spree::Api::V3::OrderSerializer, order))
        expect_contract(serialize(Spree::Api::V3::Admin::OrderSerializer, order))
      end

      it 'writes payments and refunds to the currency' do
        payment = create(:payment, order: order, amount: order.total, status: 'completed')
        refund = create(:refund, payment: payment, amount: 1)

        expect_contract(serialize(Spree::Api::V3::Admin::PaymentSerializer, payment))
        expect_contract(serialize(Spree::Api::V3::Admin::RefundSerializer, refund))
      end

      it 'writes prices as unit prices in the currency' do
        variant = create(:variant)
        variant.set_price(currency, BigDecimal('19.5'), BigDecimal('25'))
        price = variant.prices.find_by!(currency: currency, price_list_id: nil)

        expect_contract(serialize(Spree::Api::V3::PriceSerializer, price), prices: true)
        expect_contract(serialize(Spree::Api::V3::Admin::VariantSerializer, variant))
      end

      it 'writes store credit to the currency' do
        credit = create(:store_credit, store: store, currency: currency, amount: BigDecimal('15'))

        expect_contract(serialize(Spree::Api::V3::Admin::StoreCreditSerializer, credit))
      end
    end
  end

  # The dashboards format money in the admin's own language, so the
  # back-office APIs send amounts only.
  it 'leaves formatted money out of the Admin and Seller APIs, nested records included' do
    order = create(:completed_order_with_totals, store: store)
    variant = order.line_items.first.variant
    expand = { expand: %w[prices default_variant variants line_items] }

    found = {
      Spree::Api::V3::Admin::OrderSerializer => order,
      Spree::Api::V3::Seller::OrderSerializer => order,
      Spree::Api::V3::Admin::ProductSerializer => variant.product,
      Spree::Api::V3::Seller::ProductSerializer => variant.product,
      Spree::Api::V3::Admin::VariantSerializer => variant,
      Spree::Api::V3::Seller::VariantSerializer => variant
    }.to_h { |serializer, record| [serializer.name, formatted_money_paths(serialize(serializer, record, **expand))] }
      .reject { |_, paths| paths.empty? }

    expect(found).to eq({})
    expect(serialize(Spree::Api::V3::OrderSerializer, order)).to include('display_total')
  end

  # Every money display_* key at any depth, as "path.to.key".
  def formatted_money_paths(node, path = [])
    case node
    when Hash
      node.flat_map do |key, value|
        own = key.start_with?('display_') && !Spree::Api::V3::BaseSerializer::FORMATTED_LABELS.include?(key.to_sym) ? [(path + [key]).join('.')] : []
        own + formatted_money_paths(value, path + [key])
      end
    when Array then node.each_with_index.flat_map { |item, index| formatted_money_paths(item, path + [index]) }
    else []
    end
  end

  # Earnings are in the sale currency; what the account holds is in the one
  # it settles in, so a yen sale settled in dollars has no yen cents.
  it 'writes a converted seller balance in the currency of each side' do
    balance = Spree::SellerBalance.new(seller: build(:seller), currency: 'JPY', settlement_currency: 'USD',
                                       earned: BigDecimal('1500'), pending: BigDecimal('200'),
                                       payable: BigDecimal('9.87'), paid: BigDecimal('4'))

    [Spree::Api::V3::Seller::BalanceSerializer, Spree::Api::V3::Admin::SellerBalanceSerializer].each do |serializer|
      expect(serialize(serializer, balance)).to include('earned' => '1500', 'pending' => '200', 'payable' => '9.87',
                                                        'paid' => '4.00', 'balance' => '5.87')
    end
  end

  it 'writes rates as decimal strings without trailing zeros' do
    rate = create(:tax_rate, amount: BigDecimal('0.23'))
    payload = serialize(Spree::Api::V3::Admin::TaxRateSerializer, rate)

    expect(payload['rate']).to eq('0.23')
    expect(payload['rate_percent']).to eq('23')
  end

  it 'gives every currency its decimal places' do
    payload = Spree::Api::V3::CurrencySerializer.new(Money::Currency.find('KWD')).serializable_hash

    expect(payload['decimal_places']).to eq(3)
  end
end
