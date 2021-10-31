require 'spec_helper'

describe Spree::Api::V2::Platform::Webhooks::SubscriberSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { create(type) }
  let(:type) { :subscriber }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type,
        attributes: {
          active: resource.active,
          created_at: resource.created_at,
          subscriptions: resource.subscriptions,
          updated_at: resource.updated_at,
          url: resource.url
        }
      }
    )
  end
end
