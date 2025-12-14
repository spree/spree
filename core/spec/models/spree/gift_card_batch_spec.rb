require 'spec_helper'

RSpec.describe Spree::GiftCardBatch, type: :model do
  describe 'lifecycle events' do
    let(:gift_card_batch_attrs) { { codes_count: 2, prefix: 'batch_', amount: 10 } }

    describe 'gift_card_batch.created' do
      it 'publishes created event when record is created' do
        record = build(:gift_card_batch, gift_card_batch_attrs)
        expect(record).to receive(:publish_event).with('gift_card_batch.created')
        allow(record).to receive(:publish_event).with(anything)

        record.save!
      end
    end

    describe 'gift_card_batch.updated' do
      it 'publishes updated event when record is updated' do
        record = create(:gift_card_batch, gift_card_batch_attrs)
        expect(record).to receive(:publish_event).with('gift_card_batch.updated')
        allow(record).to receive(:publish_event).with(anything)

        record.touch
      end
    end

    describe 'gift_card_batch.destroyed' do
      it 'publishes destroyed event when record is destroyed' do
        record = create(:gift_card_batch, gift_card_batch_attrs)
        expect(record).to receive(:publish_event).with('gift_card_batch.destroyed', kind_of(Hash))
        allow(record).to receive(:publish_event).with(anything)

        record.destroy!
      end
    end
  end

  describe '#create_gift_cards' do
    subject(:gift_card_batch) { build(:gift_card_batch, codes_count: 2, prefix: 'batch_', amount: 10) }

    it 'generates gift cards' do
      gift_card_batch.save

      expect(gift_card_batch.gift_cards.count).to eq 2

      expect(gift_card_batch.gift_cards.pluck(:amount).uniq).to eq [gift_card_batch.amount]
      expect(gift_card_batch.gift_cards.pluck(:expires_at).uniq).to eq [gift_card_batch.expires_at]
      expect(gift_card_batch.gift_cards.take.code).to match(/batch_/)
    end
  end

  describe '#generate_gift_cards' do
    subject(:gift_card_batch) { build(:gift_card_batch, codes_count: 2, prefix: 'batch_', amount: 10) }

    context 'when codes count is less than 500' do
      it 'generates gift cards' do
        expect(gift_card_batch).to receive(:create_gift_cards)

        gift_card_batch.save
      end
    end

    context 'when codes count is greater than 500' do
      before { gift_card_batch.codes_count = 501 }

      it 'enqueues a job' do
        expect(Spree::GiftCards::BulkGenerateJob).to receive(:perform_later)

        gift_card_batch.save
      end
    end
  end
end
