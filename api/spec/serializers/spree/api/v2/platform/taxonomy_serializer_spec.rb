require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonomySerializer, retry: 3 do
  subject { described_class.new(taxonomy) }

  let(:taxonomy) { create(:taxonomy) }
  let(:taxon) { create(:taxon, taxonomy: taxonomy) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  it do
    taxons_json = taxonomy.taxons.map do |taxon|
      {
        id: taxon.id.to_s,
        type: :taxon
      }
    end

    expect(subject.serializable_hash).to eq(
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
end
