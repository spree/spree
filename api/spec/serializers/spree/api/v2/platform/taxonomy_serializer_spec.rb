require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonomySerializer, retry: 3 do
  subject { described_class.new(taxonomy).serializable_hash }

  let(:taxonomy) { create(:taxonomy) }
  let(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let(:taxons_json) do
    taxonomy.taxons.map do |taxon|
      {
        id: taxon.id.to_s,
        type: :taxon
      }
    end
  end

  it { expect(subject).to be_kind_of(Hash) }

  it do
    expect(subject).to eq(
      {
        data: {
          id: taxonomy.id.to_s,
          type: :taxonomy,
          attributes: {
            name: taxonomy.name,
            created_at: taxonomy.created_at,
            updated_at: taxonomy.updated_at,
            position: taxonomy.position,
            public_metadata: {},
            private_metadata: {}
          },
          relationships: {
            root: {
              data: {
                id: taxonomy.root.id.to_s,
                type: :taxon
              }
            },
            taxons: {
              data: taxons_json
            }
          }
        }
      }
    )
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
