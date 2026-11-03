# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::GiftCardEmailSubscriber do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { create(:line_item, order: order, product: create(:gift_card_product, store: store)) }
  let(:gift_card) { create(:gift_card, line_item: line_item, store: store) }
  let(:event) { double('Event', payload: { 'id' => gift_card.prefixed_id }) }
  let(:email) { double(deliver_later: true) }

  before do
    allow_any_instance_of(Spree::Store).to receive(:prefers_send_consumer_transactional_emails?).and_return(true)
    allow(Spree::GiftCardMailer).to receive(:issued_email).with(gift_card.id).and_return(email)
  end

  it 'sends the card as soon as it is issued' do
    described_class.new.handle(event)

    expect(email).to have_received(:deliver_later).with(no_args)
  end

  it 'waits for the date the buyer chose' do
    send_at = 3.days.from_now.change(usec: 0)
    line_item.assign_gift_card_recipient(email: 'friend@example.com', send_at: send_at)

    described_class.new.handle(event)

    expect(email).to have_received(:deliver_later).with(wait_until: send_at)
  end

  it 'stays quiet when the store suppresses consumer emails' do
    allow_any_instance_of(Spree::Store).to receive(:prefers_send_consumer_transactional_emails?).and_return(false)

    described_class.new.handle(event)

    expect(Spree::GiftCardMailer).not_to have_received(:issued_email)
  end
end
