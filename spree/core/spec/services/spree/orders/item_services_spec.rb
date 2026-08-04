require 'spec_helper'

RSpec.describe 'draft order item services' do
  let(:order) { create(:order, store: @default_store) }
  let(:variant) { create(:variant) }

  it 'registers order-side twins of the cart item services' do
    expect(Spree.order_add_item_service).to eq(Spree::Orders::AddItem)
    expect(Spree.order_update_item_service).to eq(Spree::Orders::UpdateItem)
    expect(Spree.order_remove_line_item_service).to eq(Spree::Orders::RemoveLineItem)
  end

  it 'updates quantity with recalculation and metadata without' do
    Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 1)
    line_item = order.line_items.sole

    result = Spree::Orders::UpdateItem.call(order: order, line_item: line_item, quantity: 3, metadata: { 'note' => 'gift' })

    expect(result).to be_success
    expect(line_item.reload.quantity).to eq(3)
    expect(line_item.metadata['note']).to eq('gift')
    # Recalculation persisted the order-level counters.
    expect(order.reload.total_quantity).to eq(3)

    expect(Spree::Orders::UpdateItem.call(order: order, line_item: line_item, metadata: { 'note' => 'updated' })).to be_success
    expect(line_item.reload.metadata['note']).to eq('updated')
    expect(line_item.quantity).to eq(3)
  end

  it 'adds items to a draft order' do
    result = Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 2)

    expect(result).to be_success
    expect(order.line_items.sole.quantity).to eq(2)
  end
end
