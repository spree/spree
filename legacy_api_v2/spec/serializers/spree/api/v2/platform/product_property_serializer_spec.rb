require 'spec_helper'

describe Spree::Api::V2::Platform::ProductPropertySerializer do
  subject { described_class.new(product_property) }

  let(:product_property) { create(:product_property) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: product_property.id.to_s,
          type: :product_property,
          attributes: {
            value: product_property.value,
            position: product_property.position,
            show_property: product_property.show_property,
            filter_param: product_property.filter_param,
            created_at: product_property.created_at,
            updated_at: product_property.updated_at
          }
        }
      }
    )
  end
end
