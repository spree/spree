require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonomySerializer, retry: 3 do
  subject { described_class.new(taxonomy) }

  let(:taxonomy) { create(:taxonomy) }
  let!(:root) { taxonomy.root }
  let!(:taxon) { create(:taxon, taxonomy: taxonomy) }

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
          },
          relationships: {
            root: {
              data: {
                id: root.id.to_s,
                type: :taxon
              }
            },
            taxons: {
              data: [
                {
                  id: root.id.to_s,
                  type: :taxon
                },
                {
                  id: taxon.id.to_s,
                  type: :taxon
                }
              ]
            }
          }
        }
      }
    )
  end
end
