# frozen_string_literal: true

# 5.6 → 6.0: convert incomplete orders into Spree::Cart rows
# (docs/plans/6.0-cart-order-split.md, Wave 7 — the last flip).
#
# Every order that never completed and was never canceled becomes a cart with
# the same token/binding; its money and checkout records are re-owned
# (cart_id set, order_id nulled) and the hollow order row is deleted.
# Completed and canceled orders are untouched (their cart_id stays nil).
# Orders holding payment sessions convert last so an interrupted run leaves
# the riskiest rows for the retry. Idempotent — converted orders are gone.
namespace :spree do
  desc 'Convert incomplete legacy orders into Spree::Cart rows'
  task migrate_incomplete_orders_to_carts: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 250).to_i
    stats = Hash.new(0)

    incomplete = Spree::Order.unscoped.where(completed_at: nil, canceled_at: nil)
    with_sessions_ids = incomplete.joins(:payment_sessions).distinct.ids
    plain_ids = incomplete.where.not(id: with_sessions_ids).ids

    puts "#{plain_ids.size} incomplete orders to convert (+#{with_sessions_ids.size} with payment sessions, converted last)"

    convert = lambda do |order|
      ActiveRecord::Base.transaction do
        cart = Spree::Cart.new(
          store_id: order.store_id,
          token: order.token,
          email: order.email,
          currency: order.currency,
          locale: order.locale,
          customer_id: order.user_id,
          market_id: order.market_id,
          channel_id: order.channel_id,
          ship_address_id: order.ship_address_id,
          bill_address_id: order.bill_address_id,
          accept_marketing: order.accept_marketing,
          special_instructions: order.special_instructions,
          last_ip_address: order.last_ip_address,
          gift_card_id: order.gift_card_id,
          metadata: order.metadata,
          item_total: order.item_total,
          total_quantity: order.total_quantity,
          adjustment_total: order.adjustment_total,
          included_tax_total: order.included_tax_total,
          additional_tax_total: order.additional_tax_total,
          taxable_adjustment_total: order.taxable_adjustment_total,
          non_taxable_adjustment_total: order.non_taxable_adjustment_total,
          discount_total: order.discount_total,
          fee_total: order.fee_total,
          delivery_total: order.delivery_total,
          payment_total: order.payment_total,
          total: order.total
        )
        # Raw preference write — the public setter validates pickup_enabled,
        # which must not reject historical selections.
        cart.assign_stock_location_id_preference(order.preferred_stock_location_id) if order.preferred_stock_location_id.present?
        # save!(validate: false) skips before_validation, so resolve the now
        # mandatory market/channel explicitly (legacy rows may have neither).
        cart.send(:ensure_market_presence)
        cart.send(:ensure_channel_presence)
        cart.save!(validate: false)
        cart.update_columns(created_at: order.created_at, updated_at: order.updated_at)

        # Re-own every dual-FK record. Money records move, never copy.
        [
          Spree::LineItem, Spree::Fulfillment, Spree::Payment, Spree::PaymentSession,
          Spree::StockReservation, Spree::CouponCode, Spree::OrderPromotion,
          Spree::TaxLine, Spree::Discount, Spree::Fee
        ].each do |klass|
          klass.unscoped.where(order_id: order.id).update_all(cart_id: cart.id, order_id: nil)
        end

        # Order-owned support rows that don't survive the conversion: the
        # order row must go, and these reference it without a cart leg.
        Spree::FulfillmentItem.unscoped.where(order_id: order.id).update_all(order_id: nil)
        Spree::StateChange.where(stateful_type: 'Spree::Order', stateful_id: order.id).delete_all

        order.delete
        stats[:converted] += 1
      end
    rescue StandardError => e
      stats[:errored] += 1
      puts "ERROR order #{order.number}: #{e.class} #{e.message}"
    end

    [plain_ids, with_sessions_ids].each do |ids|
      ids.each_slice(batch_size) do |slice|
        Spree::Order.unscoped.where(id: slice).each { |order| convert.call(order) }
        print '.'
      end
    end

    puts
    stats.each { |key, value| puts "#{key}: #{value}" }
    puts 'migrate_incomplete_orders_to_carts done.'
  end
end
