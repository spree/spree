require 'spec_helper'

describe Spree::Promotion::Rules::Channel, type: :model do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, store: store) }
  let(:rule) { described_class.new(promotion: promotion) }
  let(:channel) { create(:channel, store: store) }
  let(:other_channel) { create(:channel, store: store) }

  describe '#applicable?' do
    it 'returns true for orders' do
      expect(rule.applicable?(build(:order))).to be true
    end

    it 'returns false for non-orders' do
      expect(rule.applicable?('not an order')).to be false
    end
  end

  describe '#eligible?' do
    context 'when no channels are configured' do
      before { rule.preferred_channel_ids = [] }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(build(:order, store: store))
      end
    end

    context "when the order's channel is in the configured list" do
      before { rule.preferred_channel_ids = [channel.id] }

      it 'is eligible' do
        expect(rule).to be_eligible(build(:order, store: store, channel: channel))
      end
    end

    context "when the order's channel is not in the configured list" do
      before { rule.preferred_channel_ids = [channel.id] }

      it 'is not eligible' do
        expect(rule).not_to be_eligible(build(:order, store: store, channel: other_channel))
      end
    end

    context 'when the order matches one of multiple configured channels' do
      before { rule.preferred_channel_ids = [channel.id, other_channel.id] }

      it 'is eligible' do
        expect(rule).to be_eligible(build(:order, store: store, channel: other_channel))
      end
    end

    context 'when configured with prefixed IDs' do
      before { rule.preferred_channel_ids = [channel.prefixed_id] }

      it 'decodes them and matches' do
        expect(rule).to be_eligible(build(:order, store: store, channel: channel))
      end
    end
  end

  describe '#channels' do
    it 'returns the configured channels scoped to the store' do
      rule.preferred_channel_ids = [channel.id]
      expect(rule.channels).to contain_exactly(channel)
    end

    it 'returns none when unconfigured' do
      expect(rule.channels).to be_empty
    end
  end

  context 'when configured with a channel from another store' do
    let(:other_store) { create(:store) }
    let(:foreign_channel) { create(:channel, store: other_store) }

    it 'rejects the foreign ID' do
      expect { rule.preferred_channel_ids = [foreign_channel.id] }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
