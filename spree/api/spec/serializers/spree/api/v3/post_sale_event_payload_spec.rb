require 'spec_helper'

# A storefront that sends its own emails acknowledges a return or exchange
# from the webhook alone, so the payload carries the order, the reason and the
# lines (docs/plans/6.1-returns-portal.md).
RSpec.describe 'Return and exchange event payloads' do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }

  it 'embeds the order and the returned lines in a return event' do
    return_record = create(:return, order: order, store: store)

    payload = return_record.event_payload_for('return.requested')

    expect(payload.dig('order', 'email')).to eq(order.email)
    expect(payload.dig('order', 'number')).to eq(order.number)
    expect(payload['return_line_items'].first.dig('variant', 'id')).to eq(return_record.return_line_items.first.variant.prefixed_id)
  end

  it 'embeds the order and both sides of an exchange in an exchange event' do
    exchange = create(:exchange, order: order, store: store)

    payload = exchange.event_payload_for('exchange.requested')
    line = payload['exchange_line_items'].first

    expect(payload.dig('order', 'email')).to eq(order.email)
    expect(line.dig('original_variant', 'id')).to be_present
    expect(line.dig('new_variant', 'id')).to eq(exchange.exchange_line_items.first.new_variant.prefixed_id)
  end

  # A seller reads their own goods coming back, never the buyer's order.
  it 'never lets a seller expand the order' do
    return_record = create(:return, order: order, store: store)
    params = { store: store, currency: order.currency, expand: %w[order] }

    expect(Spree::Api::V3::Seller::ReturnSerializer.new(return_record, params: params).to_h).not_to have_key('order')
    expect(Spree::Api::V3::Seller::ExchangeSerializer.new(create(:exchange, order: order, store: store), params: params).to_h).not_to have_key('order')
  end
end
