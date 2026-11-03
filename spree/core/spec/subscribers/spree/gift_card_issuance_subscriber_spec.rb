require 'spec_helper'

RSpec.describe Spree::GiftCardIssuanceSubscriber do
  let(:order) { create(:completed_order_with_totals) }

  def event(name)
    Spree::Event.new(name: name, payload: { 'id' => order.prefixed_id })
  end

  it 'issues at placement when checkout already took the money' do
    expect(Spree.gift_card_issue_from_order_workflow).to receive(:call).with(order: order, paid: false)

    described_class.new.call(event('order.placed'))
  end

  it 'issues when a later payment settles the order' do
    expect(Spree.gift_card_issue_from_order_workflow).to receive(:call).with(order: order, paid: true)

    described_class.new.call(event('order.paid'))
  end
end
