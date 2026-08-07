# frozen_string_literal: true

require 'spec_helper'

# Return, Exchange and Claim all embed their reason the same way, so the three
# are covered together rather than in three near-identical files.
RSpec.describe 'reason embeds' do
  let(:store) { @default_store }
  let(:return_reason) { create(:return_reason, store: store, name: 'Too big') }
  let(:claim_reason) { create(:claim_reason, store: store, name: 'Arrived damaged') }

  def serialize(serializer, record, expand: nil)
    params = { store: store, currency: 'USD' }
    params[:expand] = expand if expand
    serializer.new(record, params: params).to_h
  end

  describe 'the store API' do
    it 'embeds a slim reason on a return, an exchange and a claim' do
      records = {
        Spree::Api::V3::ReturnSerializer => create(:return, store: store, reason: return_reason),
        Spree::Api::V3::ExchangeSerializer => create(:exchange, store: store, reason: return_reason),
        Spree::Api::V3::ClaimSerializer => create(:claim, store: store, reason: claim_reason)
      }

      records.each do |serializer, record|
        embedded = serialize(serializer, record, expand: ['reason'])['reason']

        expect(embedded.keys).to contain_exactly('id', 'name', 'active'), "#{serializer} leaked back-office fields"
        expect(embedded['name']).to eq(record.reason.name)
      end
    end

    it 'omits the reason unless it is expanded' do
      return_record = create(:return, store: store, reason: return_reason)
      payload = serialize(Spree::Api::V3::ReturnSerializer, return_record)

      expect(payload).not_to have_key('reason')
      expect(payload['reason_id']).to eq(return_reason.prefixed_id)
    end
  end

  describe 'the admin API' do
    it 'embeds the back-office reason' do
      records = {
        Spree::Api::V3::Admin::ReturnSerializer => create(:return, store: store, reason: return_reason),
        Spree::Api::V3::Admin::ExchangeSerializer => create(:exchange, store: store, reason: return_reason),
        Spree::Api::V3::Admin::ClaimSerializer => create(:claim, store: store, reason: claim_reason)
      }

      records.each do |serializer, record|
        embedded = serialize(serializer, record, expand: ['reason'])['reason']

        expect(embedded).to include('can_be_deleted', 'created_at', 'updated_at')
        expect(embedded['name']).to eq(record.reason.name)
      end
    end
  end
end
