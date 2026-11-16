require 'rails_helper'

RSpec.describe OrderSyncSubscriber do
  let(:order) { create(:completed_order_with_totals) }
  let(:event) { instance_double(Spree::Event, name: 'order.placed', payload: { 'id' => order.prefixed_id }) }

  before { stub_const('ENV', ENV.to_h.merge('ORDER_SYNC_URL' => 'https://partner.example.com/orders')) }

  it 'posts the order to ORDER_SYNC_URL' do
    expect(Net::HTTP).to receive(:post).once do |uri, body, headers|
      expect(uri.to_s).to eq('https://partner.example.com/orders')
      expect(headers).to include('Content-Type' => 'application/json')
      expect(JSON.parse(body)).to eq(
        'id' => order.prefixed_id, 'number' => order.number,
        'total' => order.total.to_s('F'), 'currency' => order.currency
      )
      Net::HTTPOK.new('1.1', '200', 'OK')
    end

    described_class.new.handle(event)
  end

  it 'does not raise when the partner is down' do
    allow(Net::HTTP).to receive(:post).and_raise(Errno::ECONNREFUSED)

    expect { described_class.new.handle(event) }.not_to raise_error
  end
end
