require 'spec_helper'

RSpec.describe Spree::Carts::RemoveOutOfStockItems do
  subject { described_class }

  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:cart) { create(:cart_with_line_items, store: store, customer: user) }
  let(:product) { cart.products.first }
  let(:variant) { cart.variants.first }
  let(:execute) { subject.call(cart: cart) }

  it 'evaluate service to success' do
    expect(execute).to be_success
  end

  it 'returns empty messages and warnings when cart is valid' do
    _cart, messages, warnings = execute.value
    expect(messages).to be_empty
    expect(warnings).to be_empty
  end

  context 'when product is archived' do
    before { product.update_columns(status: 'archive') }

    it 'removes line item and returns discontinued message' do
      _cart, messages, _warnings = execute.value
      expect(messages.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: product.name))
    end

    it 'returns structured warning with line_item_removed code' do
      _cart, _messages, warnings = execute.value
      expect(warnings.length).to eq(1)
      expect(warnings.first[:code]).to eq('line_item_removed')
      expect(warnings.first[:variant_id]).to be_present
    end
  end

  context 'when product is out of stock' do
    before { product.stock_levels.update_all(count_on_hand: 0, backorderable: false) }

    it 'removes line item and returns out of stock message' do
      _cart, messages, _warnings = execute.value
      expect(messages.to_sentence).to eq(Spree.t('cart_line_item.out_of_stock', li_name: product.name))
    end

    it 'returns structured warning with line_item_removed code' do
      _cart, _messages, warnings = execute.value
      expect(warnings.length).to eq(1)
      expect(warnings.first[:code]).to eq('line_item_removed')
    end
  end

  context 'when product is deleted' do
    before { product.delete }

    it 'removes line item and returns discontinued message' do
      _cart, messages, _warnings = execute.value
      expect(messages.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: product.name))
    end
  end

  context 'when product is discontinued' do
    before { product.update_columns(status: 'discontinued') }

    it 'removes line item and returns discontinued message' do
      _cart, messages, _warnings = execute.value
      expect(messages.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: product.name))
    end
  end

  context 'when variant is discontinued' do
    before { variant.discontinue! }

    it 'removes line item and returns discontinued message' do
      _cart, messages, _warnings = execute.value
      expect(messages.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: variant.product.name))
    end
  end

  context "when the cart holds its own stock reservation for the last unit" do
    let(:line_item) { cart.line_items.first }

    before do
      stub_store_preferences(stock_reservations_enabled: true)
      variant.stock_levels.update_all(count_on_hand: 1, backorderable: false)
      line_item.update!(quantity: 1)
      variant.stock_levels.each do |stock_level|
        create(
          :stock_reservation,
          stock_level: stock_level,
          line_item: line_item,
          cart: cart,
          quantity: 1,
          expires_at: 5.minutes.from_now
        )
      end
    end

    it 'keeps the line item in the cart' do
      _cart, messages, warnings = execute.value
      expect(messages).to be_empty
      expect(warnings).to be_empty
      expect(cart.reload.line_items).to include(line_item)
    end
  end
end
