require 'spec_helper'

RSpec.describe Spree::BaseAnalyticsEventHandler do
  let(:client) { double('client') }
  let(:user) { create(:user) }
  let(:session) { double('session', id: 'test-session-123') }
  let(:request) { double('request', remote_ip: '127.0.0.1') }
  let(:visitor_id) { 'test-visitor-123' }
  let(:handler) { described_class.new(user: user, session: session, request: request, visitor_id: visitor_id) }

  describe '#client' do
    it 'raises NotImplementedError' do
      expect { handler.client }.to raise_error(NotImplementedError)
    end
  end

  describe '#initialize' do
    it 'sets user, session and request  ' do
      expect(handler.user).to eq(user)
      expect(handler.session).to eq(session)
      expect(handler.request).to eq(request)
    end
  end

  describe '#handle_event' do
    it 'raises NotImplementedError' do
      expect { handler.handle_event('test_event') }.to raise_error(NotImplementedError)
    end
  end

  describe '#event_human_name' do
    it 'returns the label for supported events' do
      expect(handler.event_human_name('product_viewed')).to eq('Product Viewed')
      expect(handler.event_human_name('order_completed')).to eq('Order Completed')
      expect(handler.event_human_name('checkout_started')).to eq('Checkout Started')
    end

    it 'returns nil for unsupported events' do
      expect(handler.event_human_name('unsupported_event')).to be_nil
    end
  end

  describe '#identity_hash' do
    context 'when user is present' do
      it 'returns hash with user_id, visitor_id and session_id' do
        expect(handler.send(:identity_hash)).to eq({
          user_id: user.id,
          session_id: session.id,
          visitor_id: visitor_id
        })
      end
    end

    context 'when user is not present' do
      let(:handler) { described_class.new(session: session, visitor_id: visitor_id) }

      it 'returns hash with nil user_id, visitor_id and session_id' do
        expect(handler.send(:identity_hash)).to eq({
          user_id: nil,
          visitor_id: visitor_id,
          session_id: session.id
        })
      end
    end
  end
end
