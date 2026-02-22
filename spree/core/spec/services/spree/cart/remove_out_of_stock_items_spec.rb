require 'spec_helper'

RSpec.describe Spree::Cart::RemoveOutOfStockItems do
  subject { described_class }

  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_totals, store: store, user: user) }
  let(:execute) { subject.call(order: order) }

  it 'evaluate service to success' do
    expect(execute).to be_success
  end

  it 'removes line item and render discontinued flash message' do
    product = order.products.first
    product.update_columns(status: 'archive')
    expect(execute.value.last.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: product.name))
  end

  it 'removes line item and render out of stock flash message' do
    product = order.products.first
    product.stock_items.update_all(count_on_hand: 0, backorderable: false)
    expect(execute.value.last.to_sentence).to eq(Spree.t('cart_line_item.out_of_stock', li_name: product.name))
  end

  it 'renders discontinued flash message when line item is deleted' do
    product = order.products.first
    product.delete
    expect(execute.value.last.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: product.name))
  end

  it 'renders discontinued flash message when line item is discontinued' do
    product = order.products.first
    product.update_columns(status: 'discontinued')
    expect(execute.value.last.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: product.name))
  end

  it 'renders discontinued flash message when a variant is discontinued' do
    variant = order.variants.first
    variant.discontinue!
    expect(execute.value.last.to_sentence).to eq(Spree.t('cart_line_item.discontinued', li_name: variant.product.name))
  end
end
