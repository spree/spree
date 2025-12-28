require 'spec_helper'

describe Spree::Api::V2::Platform::Webhooks::EventSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { create(type, subscriber: subscriber) }
  let(:subscriber) { create(:subscriber) }
  let(:type) { :event }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type,
        attributes: {
          created_at: resource.created_at,
          execution_time: resource.execution_time,
          name: resource.name,
          request_errors: resource.request_errors,
          response_code: resource.response_code,
          success: resource.success,
          updated_at: resource.updated_at,
          url: resource.url
        },
        relationships: {
          subscriber: {
            data: {
              id: subscriber.id.to_s,
              type: :subscriber
            }
          }
        }
      }
    )
  end
end
