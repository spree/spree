require 'spec_helper'

RSpec.describe Spree::OrderActivitySubscriber, events: true do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store, line_items_count: 2) }
  let(:line_item) { order.line_items.first }
  let(:admin) { create(:admin_user) }

  def publish(record, name)
    record.publish_event(name)
  end

  it 'records a step with who did it' do
    Spree::Current.actor = admin
    publish(order, 'order.approved')

    activity = order.activities.sole
    expect(activity).to have_attributes(kind: 'order.approved', category: 'order', actor: admin)
  end

  it 'records a step nobody signed in for without an actor' do
    publish(order, 'order.placed')

    expect(order.activities.sole).to have_attributes(kind: 'order.placed', actor: nil)
    expect(order.activities.sole.details).to include('total' => Spree::Money::Rounding.format(order.total, order.currency))
  end

  it 'ignores events it has no kind for' do
    publish(order, 'order.updated')

    expect(order.activities).to be_empty
  end

  it 'records a settled payment with its method and amount' do
    payment = create(:payment, order: order, cart: nil, amount: order.total)
    publish(payment, 'payment.completed')

    expect(order.activities.sole).to have_attributes(kind: 'payment.completed', category: 'payments')
    expect(order.activities.sole.details).to include('payment_id' => payment.prefixed_id,
                                                     'amount' => Spree::Money::Rounding.format(payment.amount, order.currency))
  end

  it 'records a change applied in one call once, as confirmed' do
    Spree::Current.actor = admin
    change = Spree::OrderChanges::Apply.call(order: order, requested_by: admin,
                                             actions: [{ kind: 'update_item', line_item: line_item, quantity: 2 }]).value

    expect(order.activities.reload.map(&:kind)).to eq(['order_change.confirmed'])
    expect(order.activities.sole).to have_attributes(order_change: change, actor: admin)
  end

  it 'records a change that waited, then its confirmation' do
    change = Spree::OrderChanges::Apply.call(order: order, confirm: false,
                                             actions: [{ kind: 'update_item', line_item: line_item, quantity: 2 }]).value
    Spree::OrderChanges::Confirm.call(order_change: change)

    expect(order.activities.reload.map(&:kind)).to eq(%w[order_change.requested order_change.confirmed])
  end

  it 'nests a return’s restock under the return rather than recording the change' do
    return_record = create(:return, order: order)
    change = Spree::OrderChanges::Apply.call(order: order, post_sale_record: return_record,
                                             actions: [{ kind: 'receive_item', variant: line_item.variant, quantity: 1 }]).value
    publish(return_record, 'return.received')

    expect(order.activities.reload.map(&:kind)).to eq(['return.received'])
    expect(order.activities.sole).to have_attributes(order_change: change, category: 'returns')
    expect(order.activities.sole.details).to include('number' => return_record.number)
  end

  it 'leaves nothing behind for a step that rolls back' do
    ApplicationRecord.transaction do
      publish(order, 'order.approved')
      raise ActiveRecord::Rollback
    end

    expect(order.activities.reload).to be_empty
  end

  it 'never fails the step when an entry cannot be written' do
    Spree.order_activity_kinds.register('order.approved', category: 'order') { raise 'broken builder' }
    allow(Rails.error).to receive(:report)

    expect { publish(order, 'order.approved') }.not_to raise_error
    expect(Rails.error).to have_received(:report).with(an_instance_of(RuntimeError), hash_including(source: 'spree.order_activities'))
  ensure
    Spree.instance_variable_set(:@order_activity_kinds, nil)
  end

  it 'records a kind an extension registers' do
    Spree.order_activity_kinds.register('order.resend_confirmation_email', category: 'emails') do |event|
      { order: Spree::Order.find_by_prefix_id(event.payload['id']), details: { resent: true } }
    end
    publish(order, 'order.resend_confirmation_email')

    expect(order.activities.sole).to have_attributes(kind: 'order.resend_confirmation_email', category: 'emails')
  ensure
    Spree.instance_variable_set(:@order_activity_kinds, nil)
  end

  it 'never stores a customer’s name or email' do
    publish(order, 'order.placed')

    expect(order.activities.sole.details.to_json).not_to include(order.email)
  end
end
