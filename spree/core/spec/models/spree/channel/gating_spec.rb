require 'spec_helper'

RSpec.describe Spree::Channel::Gating, type: :model do
  let(:store) { create(:store) }
  let(:channel) { create(:channel, store: store) }

  describe '#resolved_storefront_access' do
    it 'defaults to public when neither channel nor store override it' do
      expect(channel.resolved_storefront_access).to eq('public')
    end

    it 'returns the channel override when present' do
      channel.update!(preferred_storefront_access: 'login_required')
      expect(channel.resolved_storefront_access).to eq('login_required')
    end

    it 'falls back to the store value when the channel is unset' do
      store.update!(preferred_storefront_access: 'prices_hidden')
      expect(channel.resolved_storefront_access).to eq('prices_hidden')
    end

    it 'prefers the channel value over the store value' do
      store.update!(preferred_storefront_access: 'login_required')
      channel.update!(preferred_storefront_access: 'public')
      expect(channel.resolved_storefront_access).to eq('public')
    end
  end

  describe '#resolved_guest_checkout' do
    it 'is nil on the channel by default (inherit)' do
      expect(channel.preferred_guest_checkout).to be_nil
    end

    it 'falls back to the store default (true) when the channel is unset' do
      expect(channel.resolved_guest_checkout).to be true
    end

    it 'returns the channel override even when the store allows guests' do
      channel.update!(preferred_guest_checkout: false)
      expect(channel.resolved_guest_checkout).to be false
    end

    it 'follows the store when the store forbids guests and the channel is unset' do
      store.update!(preferred_guest_checkout: false)
      expect(channel.resolved_guest_checkout).to be false
    end

    it 'clears the override (restores inheritance) when written blank' do
      store.update!(preferred_guest_checkout: false)
      channel.update!(preferred_guest_checkout: true)
      expect(channel.resolved_guest_checkout).to be true

      # A boolean preference would coerce this to false; the override must
      # instead delete the key so the store value applies again.
      channel.update!(preferred_guest_checkout: '')
      expect(channel.preferred_guest_checkout).to be_nil
      expect(channel.resolved_guest_checkout).to be false
    end
  end

  describe 'storefront_access validation' do
    it 'allows a blank value (inherit)' do
      channel.preferred_storefront_access = ''
      expect(channel).to be_valid
    end

    it 'allows every known level' do
      Spree::Channel::Gating::STOREFRONT_ACCESS.each do |level|
        channel.preferred_storefront_access = level
        expect(channel).to be_valid, "expected #{level} to be a valid storefront_access"
      end
    end

    it 'rejects an unknown level' do
      channel.preferred_storefront_access = 'secret'
      expect(channel).not_to be_valid
      expect(channel.errors[:preferred_storefront_access]).to be_present
    end
  end

  describe 'predicates' do
    it '#storefront_prices_hidden? is true only for prices_hidden' do
      channel.update!(preferred_storefront_access: 'prices_hidden')
      expect(channel.storefront_prices_hidden?).to be true
      expect(channel.storefront_login_required?).to be false
    end

    it '#storefront_login_required? is true only for login_required' do
      channel.update!(preferred_storefront_access: 'login_required')
      expect(channel.storefront_login_required?).to be true
      expect(channel.storefront_prices_hidden?).to be false
    end
  end
end
