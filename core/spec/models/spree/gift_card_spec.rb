# == Schema Information
#
# Table name: spree_gift_cards
#
#  id                   :bigint           not null, primary key
#  amount               :decimal(10, 2)   not null
#  amount_remaining     :decimal(10, 2)   default(0.0), not null
#  code                 :string           not null
#  expires_at           :date
#  minimum_order_amount :decimal(10, 2)   default(0.0)
#  state                :integer          default("active"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  gift_card_batch_id   :bigint
#  store_credit_id      :bigint
#  store_id             :bigint           not null
#  tenant_id            :bigint           not null
#  user_id              :bigint
#
require 'rails_helper'

RSpec.describe Spree::GiftCard, type: :model do
  describe 'before_destroy :ensure_can_be_deleted' do
    it "ensures a used gift card can't be destroyed" do
      expect(create(:gift_card, state: :redeemed).destroy).to be(false)
      expect(create(:gift_card, state: :partialy_redeemed).destroy).to be(false)
      expect(create(:gift_card, state: :active).destroy).to be_destroyed
      expect(create(:gift_card, state: :canceled).destroy).to be_destroyed
    end

    it 'adds an error' do
      gift_card = create(:gift_card, state: :redeemed)
      gift_card.destroy

      expect(gift_card).to_not be_destroyed
      expect(gift_card.errors.messages).to eq(base: ["Can't delete a used gift card"])
    end
  end

  describe 'after_commit :track_gift_card_issued' do
    subject do
      create(
        :gift_card,
        user: user,
        code: 'gift-card-code-1234',
        amount: 10,
        minimum_order_amount: 50,
        expires_at: 2.days.from_now
      )
    end

    before do
      Sidekiq::Worker.clear_all
    end

    context 'with klaviyo integration' do
      let!(:klaviyo_integration) { create(:klaviyo_integration) }

      context 'without user assigned' do
        let(:user) { nil }

        it 'skips tracking' do
          subject
          expect(Klaviyo::CreateEventWorker.jobs).to be_empty
        end
      end

      context 'with user assigned' do
        let(:user) { create(:user) }

        it 'tracks the gift card issued' do
          subject

          expect(Klaviyo::CreateEventWorker.jobs.count).to eq(1)
          expect(Klaviyo::CreateEventWorker.jobs.last['args']).to eq([klaviyo_integration.id, 'Gift Card Issued', subject.id, 'Spree::GiftCard', user.email])
        end
      end
    end

    context 'without klaviyo integration' do
      let(:user) { create(:user) }

      it 'skips tracking' do
        subject
        expect(Klaviyo::CreateEventWorker.jobs).to be_empty
      end
    end
  end

  describe '#display_state' do
    context 'when expired' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.ago, state: :active) }

      it 'returns expired' do
        expect(gift_card.display_state).to eq 'expired'
      end
    end

    context 'when active' do
      let(:gift_card) { build(:gift_card, expires_at: 1.day.from_now, state: :active) }

      it 'returns active' do
        expect(gift_card.display_state).to eq 'active'
      end
    end
  end
end
