require 'spec_helper'

RSpec.describe Spree::BaseAnalyticsEventHandler do
  let(:client) { double('client') }
  let(:user) { create(:user) }
  let(:session_id) { 'test-session-123' }
  let(:handler) { described_class.new(client, user: user, session_id: session_id) }

  describe '.client_method' do
    it 'raises NotImplementedError' do
      expect { described_class.client_method }.to raise_error(NotImplementedError)
    end
  end

  describe '#initialize' do
    it 'sets client, user and session_id' do
      expect(handler.client).to eq(client)
      expect(handler.user).to eq(user)
      expect(handler.session_id).to eq(session_id)
    end
  end

  describe '#handle_event' do
    it 'raises NotImplementedError' do
      expect { handler.handle_event('test_event') }.to raise_error(NotImplementedError)
    end
  end

  describe '#event_label' do
    it 'returns the label for supported events' do
      expect(handler.event_label('product_viewed')).to eq('Product Viewed')
      expect(handler.event_label('order_completed')).to eq('Order Completed')
      expect(handler.event_label('checkout_started')).to eq('Checkout Started')
    end

    it 'returns nil for unsupported events' do
      expect(handler.event_label('unsupported_event')).to be_nil
    end
  end

  describe '#identity_hash' do
    context 'when user is present' do
      it 'returns hash with user_id and session_id' do
        expect(handler.send(:identity_hash)).to eq({
          user_id: user.id,
          session_id: session_id
        })
      end
    end

    context 'when user is not present' do
      let(:handler) { described_class.new(client, session_id: session_id) }

      it 'returns hash with nil user_id and session_id' do
        expect(handler.send(:identity_hash)).to eq({
          user_id: nil,
          session_id: session_id
        })
      end
    end
  end
end
