require 'spec_helper'

describe Spree::PriceRules::ChannelRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:channel_price_rule, price_list: price_list) }
  # Channels are store-scoped via `parse_on_set: normalize_id_preference(scope: …)`,
  # so all channels referenced here live in the same store as the rule.
  let(:channel) { create(:channel, store: price_list.store) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    context 'when channel_ids preference is empty' do
      before { rule.preferred_channel_ids = [] }

      it 'returns true for any channel' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', channel: channel)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns true even when the context has no channel' do
        # An unrestricted rule applies everywhere, including channel-less
        # contexts. Stub the fallback so no channel is inferred.
        allow(Spree::Current).to receive(:channel).and_return(nil)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', channel: nil)
        expect(rule.applicable?(context)).to be true
      end
    end

    context 'when channel_ids preference is set' do
      before { rule.preferred_channel_ids = [channel.id] }

      it 'returns true when context channel matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', channel: channel)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context channel does not match' do
        other_channel = create(:channel, store: price_list.store)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', channel: other_channel)
        expect(rule.applicable?(context)).to be false
      end

      it 'returns false when context has no channel' do
        # `Spree::Pricing::Context` falls back to `Spree::Current.channel`
        # when none is passed, so stub the fallback to truly mimic the
        # no-channel case.
        allow(Spree::Current).to receive(:channel).and_return(nil)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', channel: nil)
        expect(rule.applicable?(context)).to be false
      end
    end
  end

  describe '#preferred_channel_ids=' do
    it 'decodes prefixed channel IDs to raw IDs' do
      rule.preferred_channel_ids = [channel.prefixed_id]
      expect(rule.preferred_channel_ids).to eq([channel.id.to_s])
    end

    it 'accepts a comma-separated string' do
      other_channel = create(:channel, store: price_list.store)
      rule.preferred_channel_ids = "#{channel.prefixed_id},#{other_channel.prefixed_id}"
      expect(rule.preferred_channel_ids).to contain_exactly(channel.id.to_s, other_channel.id.to_s)
    end

    it 'raises when given an unknown prefixed ID' do
      expect { rule.preferred_channel_ids = ['ch_doesnotexist'] }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'rejects a channel that belongs to another store' do
      other_store = create(:store)
      cross_store_channel = create(:channel, store: other_store)
      expect {
        rule.preferred_channel_ids = [cross_store_channel.prefixed_id]
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#channels' do
    let(:other_channel) { create(:channel, store: price_list.store) }

    it 'returns the channels matching the preferred IDs' do
      rule.preferred_channel_ids = [channel.id, other_channel.id]
      expect(rule.channels).to contain_exactly(channel, other_channel)
    end

    it 'returns empty when no channels are set' do
      rule.preferred_channel_ids = []
      expect(rule.channels).to be_empty
    end
  end
end
