require 'spec_helper'

describe Spree::Api::V2::Platform::TaxCategorySerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(resource, params: serializer_params).serializable_hash }

  let(:resource) { create(:tax_category) }
  let(:type) { :tax_category }

  it do
    expect(subject).to eq(
      data: {
        id: resource.id.to_s,
        type: type,
        attributes: {
          name: resource.name,
          description: resource.description,
          is_default: resource.is_default,
          deleted_at: resource.deleted_at,
          created_at: resource.created_at,
          updated_at: resource.updated_at,
          tax_code: nil
        },
        relationships: {
          tax_rates: {
            data: []
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
