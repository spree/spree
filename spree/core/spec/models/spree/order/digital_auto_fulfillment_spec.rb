require 'spec_helper'

describe 'Digital auto-fulfillment on order completion', type: :model do
  let(:store) { @default_store }
  let(:digital_product) { create(:digital_product, stores: [store]) }
  let(:digital_variant) { create(:variant, product: digital_product, digitals: [create(:digital)]) }
  let(:order) { create(:order_with_line_items, store: store, variants: [digital_variant], line_items_count: 1) }

  before do
    # Route the fulfillment through a digital delivery method so the provider
    # strategy resolves to Digital.
    digital_method = create(:digital_shipping_method)
    order.fulfillments.each do |fulfillment|
      rate = fulfillment.delivery_rates.create!(delivery_method: digital_method, cost: 0, selected: false)
      fulfillment.delivery_rates.where.not(id: rate.id).update_all(selected: false)
      rate.update!(selected: true)
      fulfillment.reload
    end
  end

  it 'fulfills the digital fulfillment and creates links per quantity on finalize' do
    line_item = order.line_items.first
    line_item.update_columns(quantity: 2)
    order.fulfillment_items.update_all(quantity: 2)

    order.finalize!

    fulfillment = order.fulfillments.reload.first
    expect(fulfillment).to be_fulfilled
    expect(line_item.digital_links.reload.count).to eq(2)
    expect(order.reload.fulfillment_status).to eq('fulfilled')
  end

  it 'is idempotent across repeated finalization side effects' do
    order.finalize!
    fulfillment = order.fulfillments.reload.first

    expect { fulfillment.provider.create_fulfillment(fulfillment) }.
      not_to change { Spree::DigitalLink.count }
  end
end
