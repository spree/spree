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

  describe 'negotiated (manual) prices' do
    it 'adds an item at a negotiated price, stamped manual' do
      result = Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 10, price: '7.20')

      expect(result).to be_success
      line_item = order.line_items.sole
      expect(line_item.price).to eq(7.2)
      expect(line_item.price_source).to eq('manual')
      expect(line_item.price_list_id).to be_nil
    end

    it 'sets a negotiated price on an existing line and keeps it through quantity changes' do
      Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 1)
      line_item = order.line_items.sole

      result = Spree::Orders::UpdateItem.call(order: order, line_item: line_item, price: '7.20')

      expect(result).to be_success
      expect(line_item.reload.price).to eq(7.2)
      expect(line_item.price_source).to eq('manual')
      # Order totals follow the negotiated price.
      expect(order.reload.item_total).to eq(7.2)

      Spree::Orders::UpdateItem.call(order: order, line_item: line_item, quantity: 4)

      expect(line_item.reload.price).to eq(7.2)
      expect(order.reload.item_total).to eq(28.8)
    end

    it 'reverts to catalog pricing on an explicit nil price' do
      Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 1, price: '7.20')
      line_item = order.line_items.sole
      catalog_price = variant.price_in(order.currency).amount

      result = Spree::Orders::UpdateItem.call(order: order, line_item: line_item, price: nil)

      expect(result).to be_success
      expect(line_item.reload.price).to eq(catalog_price)
      expect(line_item.price_source).to be_nil
    end

    # BigDecimal parses 'NaN' and 'Infinity' and neither is negative, so
    # without a finite? check they reach the insert and fail as a 500.
    ['12,50', 'NaN', 'Infinity', '-1'].each do |bad_price|
      it "refuses a price of #{bad_price} rather than coercing it, and says why" do
        Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 1)
        line_item = order.line_items.sole

        result = Spree::Orders::UpdateItem.call(order: order, line_item: line_item, price: bad_price)

        expect(result).to be_failure
        expect(result.error.to_s).to be_present
        expect(line_item.reload.price_source).to be_nil
      end

      it "refuses adding an item priced #{bad_price}" do
        result = Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 1, price: bad_price)

        expect(result).to be_failure
        expect(result.error.to_s).to be_present
        expect(order.reload.line_items).to be_empty
      end
    end

    it 'refuses a price override once the order is placed, saying why' do
      Spree::Orders::AddItem.call(order: order, variant: variant, quantity: 1)
      line_item = order.line_items.sole
      order.update_columns(status: 'placed', completed_at: Time.current)

      result = Spree::Orders::UpdateItem.call(order: order, line_item: line_item, price: '7.20')

      expect(result).to be_failure
      expect(result.error.to_s).to include('placed order')
      expect(line_item.reload.price_source).to be_nil

      add_result = Spree::Orders::AddItem.call(order: order, variant: create(:variant), quantity: 1, price: '7.20')
      expect(add_result).to be_failure
      expect(add_result.error.to_s).to include('placed order')
    end
  end
end
