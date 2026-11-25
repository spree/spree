# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PaymentCaptureEventSerializer do
  let(:store) { @default_store }

  def payload_for(capture_event)
    described_class.new(capture_event, params: { store: store, currency: 'USD' }).to_h
  end

  it 'exposes the status' do
    expect(payload_for(create(:payment_capture_event, :requested))['status']).to eq('requested')
  end

  it 'reads an empty status as completed' do
    capture_event = create(:payment_capture_event).tap { |event| event.update_column(:status, nil) }

    expect(payload_for(capture_event.reload)['status']).to eq('completed')
  end
end
