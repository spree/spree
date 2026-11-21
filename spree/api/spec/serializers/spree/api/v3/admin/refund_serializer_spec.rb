# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::RefundSerializer do
  let(:store) { @default_store }

  def payload_for(refund)
    described_class.new(refund, params: { store: store, currency: 'USD' }).to_h
  end

  it 'exposes the status and the reason a refund failed' do
    refund = create(:refund, :failed, amount: 10, failure_reason: 'Account closed')

    expect(payload_for(refund)).to include('status' => 'failed', 'failure_reason' => 'Account closed')
  end

  it 'exposes a requested refund with no failure reason' do
    expect(payload_for(create(:refund, :requested, amount: 10))).to include('status' => 'requested', 'failure_reason' => nil)
  end

  it 'leaves both out of the Store API' do
    store_payload = Spree::Api::V3::RefundSerializer.new(create(:refund, amount: 10), params: { store: store, currency: 'USD' }).to_h

    expect(store_payload.keys).not_to include('status', 'failure_reason')
  end
end
