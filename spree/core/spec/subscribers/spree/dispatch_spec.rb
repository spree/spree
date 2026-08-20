require 'spec_helper'

# Subscriber specs call their handler methods directly, which proves the body
# works but never that the event reaches it. Events are disabled by default in
# the test environment, so the dispatch itself — the declared pattern, the
# payload the publisher sends, and the record lookup the handler does with it —
# runs unexercised until production.
#
# This publishes each declared event for real and asserts the handler ran.
RSpec.describe 'subscriber dispatch', events: true do
  include ActiveJob::TestHelper

  # @param klass [Class] the subscriber
  # @param method_name [Symbol] whatever it declares — #handle, or the named
  #   method registered through `on`
  # @return [Boolean] whether publishing reached the handler
  def reaches_handler?(klass, method_name, event_name)
    reached = false
    original = klass.instance_method(method_name)
    klass.define_method(method_name) do |event|
      reached = true if event.name == event_name
      original.bind(self).call(event)
    end

    # Async subscribers dispatch through ActiveJob, so the job has to run
    # before the handler is reached at all.
    perform_enqueued_jobs { yield }
    reached
  ensure
    klass.define_method(method_name, original)
  end

  let(:store) { @default_store }

  describe 'order.placed' do
    let(:order) { create(:order_with_line_items, store: store) }

    it 'reaches the synchronous completion subscriber' do
      expect(reaches_handler?(Spree::OrderPlacedSubscriber, :handle, 'order.placed') do
        order.publish_event('order.placed')
      end).to be(true)
    end

    it 'reaches the asynchronous product metrics subscriber' do
      expect(reaches_handler?(Spree::ProductMetricsSubscriber, :refresh_product_metrics, 'order.placed') do
        order.publish_event('order.placed')
      end).to be(true)
    end
  end

  describe 'payment events' do
    let(:order) { create(:order_with_line_items, store: store) }

    # Regression guard for the four-recomputations-per-capture duplication:
    # this subscriber is the only writer of payment_status now, so its
    # dispatch has to survive refactors of the payment lifecycle.
    it 'reaches the order status subscriber when a payment settles' do
      payment = create(:payment, order: order, amount: order.total, status: 'checkout')

      expect(reaches_handler?(Spree::OrderStatusSubscriber, :handle, 'payment.completed') do
        payment.complete!
      end).to be(true)
    end
  end

  # Cart-owned payments were where the events-off blind spot bit hardest:
  # a subscriber reached for order.paid? on a payment whose order is nil,
  # and nothing caught it because the handler never ran in test.
  describe 'a payment that settles on a cart' do
    let(:cart) { create(:cart, store: store) }

    before do
      create(:line_item, order: cart, price: 10, quantity: 1)
      cart.recalculate_totals!
    end

    it 'settles without reaching for the order it does not have' do
      payment = create(:payment, order: nil, cart: cart, amount: 10,
                                 payment_method: create(:check_payment_method, store: store),
                                 status: 'checkout')

      expect { perform_enqueued_jobs { payment.complete! } }.not_to raise_error
      expect(cart.reload.payment_total).to eq(10)
    end
  end

  describe 'invitation events' do
    it 'reaches the invitation email subscriber on create' do
      inviter = create(:admin_user)

      expect(reaches_handler?(Spree::InvitationEmailSubscriber, :send_invitation_email, 'invitation.created') do
        create(:invitation, inviter: inviter, resource: store)
      end).to be(true)
    end
  end
end
