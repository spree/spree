# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PaymentSerializer do
  let(:store) { @default_store }
  let(:payment) { create(:payment, status: 'requested') }

  subject(:payload) { described_class.new(payment, params: { store: store, currency: 'USD' }).to_h }

  it 'names a requested capture' do
    create(:payment_capture_event, :requested, payment: payment)

    expect(payload).to include('status' => 'requested', 'requested_action' => 'capture')
  end

  it 'names a requested void' do
    expect(payload['requested_action']).to eq('void')
  end

  it 'is null for a payment that is not waiting on its provider' do
    payment.update_column(:status, 'pending')

    expect(payload['requested_action']).to be_nil
  end
end
