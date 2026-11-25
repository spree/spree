require 'spec_helper'

RSpec.describe Spree::GiftCards::PublishCreatedEventsJob, type: :job, events: true do
  let(:batch) { create(:gift_card_batch, codes_count: 3, prefix: 'batch_', amount: 10) }
  let(:gift_cards) { batch.gift_cards.order(:id).to_a }
  let(:published) { [] }

  before do
    batch
    Spree::Events.subscribe('gift_card.created', async: false) { |event| published << event.payload['id'] }
    Spree::Events.activate!
  end

  after { Spree::Events.reset! }

  it 'publishes gift_card.created for every card in the batch' do
    described_class.perform_now(batch.id)

    expect(published).to eq(gift_cards.map(&:prefixed_id))
  end

  it 'publishes only for the cards after after_id' do
    described_class.perform_now(batch.id, after_id: gift_cards.first.id)

    expect(published).to eq(gift_cards.drop(1).map(&:prefixed_id))
  end

  it 'reports a card that fails to publish and goes on to the rest' do
    failing = gift_cards.second
    allow_any_instance_of(Spree::GiftCard).to receive(:publish_event).and_wrap_original do |original, *args|
      raise ArgumentError, 'serializer blew up' if original.receiver.id == failing.id

      original.call(*args)
    end
    allow(Rails.error).to receive(:report)

    described_class.perform_now(batch.id)

    expect(published).to eq([gift_cards.first, gift_cards.third].map(&:prefixed_id))
    expect(Rails.error).to have_received(:report).with(kind_of(ArgumentError), hash_including(context: { gift_card_id: failing.id }))
  end

  it 'resumes after the last published card when a retryable error interrupts it' do
    calls = 0
    allow_any_instance_of(Spree::GiftCard).to receive(:publish_event).and_wrap_original do |original, *args|
      calls += 1
      raise ActiveRecord::ConnectionFailed, 'connection lost' if calls == 2

      original.call(*args)
    end

    perform_enqueued_jobs { described_class.perform_later(batch.id) }

    expect(published).to eq(gift_cards.map(&:prefixed_id))
  end
end
