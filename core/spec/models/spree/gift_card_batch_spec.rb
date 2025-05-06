# == Schema Information
#
# Table name: spree_gift_card_batches
#
#  id                   :bigint           not null, primary key
#  amount               :decimal(10, 2)   default(10.0), not null
#  codes_count          :integer          default(1), not null
#  expires_at           :date
#  minimum_order_amount :decimal(10, 2)   default(0.0)
#  prefix               :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  tenant_id            :bigint           not null
#
require 'rails_helper'

RSpec.describe Spree::GiftCardBatch, type: :model do
  describe '#create_gift_cards' do
    subject(:gift_card_batch) { build(:gift_card_batch, codes_count: 2, prefix: 'batch_', amount: 10) }

    it 'generates gift cards' do
      gift_card_batch.save

      expect(gift_card_batch.gift_cards.count).to eq 2

      expect(gift_card_batch.gift_cards.pluck(:amount).uniq).to  eq [gift_card_batch.amount]
      expect(gift_card_batch.gift_cards.pluck(:amount_remaining).uniq).to  eq [gift_card_batch.amount]
      expect(gift_card_batch.gift_cards.pluck(:expires_at).uniq).to  eq [gift_card_batch.expires_at]
      expect(gift_card_batch.gift_cards.take.code).to  match(/batch_/)
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
        expect(Spree::GiftCards::BulkGenerateWorker).to receive(:perform_async)

        gift_card_batch.save
      end
    end
  end
end
