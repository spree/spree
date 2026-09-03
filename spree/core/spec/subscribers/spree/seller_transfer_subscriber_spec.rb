require 'spec_helper'

# The ledger's trigger, exercised through the events it actually listens to
# rather than by calling the workflow — the wiring is the thing most likely to
# be wrong, and it fails silently when it is.
RSpec.describe Spree::SellerTransferSubscriber, :events do
  let(:store) { @default_store }
  let(:seller) { create(:seller, :approved, store: store) }

  def seller_order
    order = create(:order, store: store, seller: seller)
    create(:line_item, order: order)
    order.update_columns(total: 100, status: 'placed', completed_at: Time.current)
    order.reload
  end

  it 'credits the seller when the order’s goods go out' do
    order = seller_order
    create(:fulfillment, order: order, cart: nil, status: 'fulfilled')

    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) { order.publish_event('order.fulfilled') }

    expect(seller.balance('USD')).to eq(100)
  end

  # order.fulfilled is dual-emitted under the legacy name order.shipped for one
  # release. Listening to both would credit twice; the unique index would
  # refuse the second, but relying on that is a rescue rather than a design.
  it 'does not credit again on the legacy event name' do
    order = seller_order
    create(:fulfillment, order: order, cart: nil, status: 'fulfilled')

    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
      order.publish_event('order.fulfilled')
      order.publish_event('order.shipped')
    end

    expect(Spree::SellerTransfer.count).to eq(1)
  end

  it 'leaves the operator’s own order alone' do
    order = create(:order, store: store)
    order.update_columns(status: 'placed', completed_at: Time.current)
    create(:fulfillment, order: order, cart: nil, status: 'fulfilled')

    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) { order.publish_event('order.fulfilled') }

    expect(Spree::SellerTransfer.count).to eq(0)
  end

  describe 'a refund afterwards' do
    it 'takes back what it gave' do
      order = seller_order
      create(:fulfillment, order: order, cart: nil, status: 'fulfilled')
      payment = create(:payment, order: order, amount: 100, status: 'completed')

      perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
        order.publish_event('order.fulfilled')
        create(:refund, payment: payment, order: order, amount: 40)
      end

      expect(seller.balance('USD')).to eq(60)
    end
  end
end
