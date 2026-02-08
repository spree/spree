# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ReturnAuthorizationSerializer do
  let(:return_authorization) { create(:return_authorization) }

  subject { described_class.serialize(return_authorization) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(return_authorization.prefix_id)
      expect(subject[:number]).to eq(return_authorization.number)
    end

    it 'includes state as string' do
      expect(subject[:state]).to be_a(String)
    end

    it 'includes foreign keys' do
      expect(subject[:order_id]).to eq(return_authorization.order&.prefix_id)
      expect(subject[:stock_location_id]).to eq(return_authorization.stock_location&.prefix_id)
      expect(subject).to have_key(:return_authorization_reason_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    it 'does not include associations' do
      expect(subject).not_to have_key(:return_items)
    end
  end
end
