require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonomySerializer do
  subject { described_class.new(taxonomy) }

  let(:taxonomy) { create(:taxonomy) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    expect(subject.serializable_hash).to eq(
      {
        data: {
          id: taxonomy.id.to_s,
          type: :taxonomy,
          attributes: {
            name: taxonomy.name,
            created_at: taxonomy.created_at,
            updated_at: taxonomy.updated_at,
            position: taxonomy.position
          }
        }
      }
    )
  end
end
