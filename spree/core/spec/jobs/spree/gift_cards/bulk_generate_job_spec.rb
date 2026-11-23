require 'spec_helper'

describe Spree::GiftCards::BulkGenerateJob, type: :job do
  subject { described_class.new }

  describe '#perform' do
    let(:gift_card_batch) { create(:gift_card_batch, codes_count: 2, prefix: 'batch_', amount: 10) }

    it 'generates gift cards' do
      expect { subject.perform(gift_card_batch.id) }.to change(Spree::GiftCard, :count).by(2)
    end

    context 'with events', events: true do
      let(:published) { [] }

      before do
        gift_card_batch.update_column(:codes_count, 4)
        Spree::Events.subscribe('gift_card.created', async: false) { |event| published << event.payload['id'] }
        Spree::Events.activate!
      end

      after { Spree::Events.reset! }

      it 'publishes gift_card.created for the cards it generates' do
        subject.perform(gift_card_batch.id)

        expect(published.size).to eq(2)
      end

      it 'stays silent when the batch was created with lifecycle events off' do
        subject.perform(gift_card_batch.id, publish_events: false)

        expect(gift_card_batch.gift_cards.count).to eq(4)
        expect(published).to be_empty
      end
    end
  end
end
