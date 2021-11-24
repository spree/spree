require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(taxon, params: serializer_params).serializable_hash }

  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:taxon) { create(:taxon, products: create_list(:product, 2, stores: [store]), taxonomy: taxonomy) }
  let!(:children) { [create(:taxon, parent: taxon, taxonomy: taxonomy), create(:taxon, parent: taxon, taxonomy: taxonomy)] }

  it { expect(subject).to be_kind_of(Hash) }

  context 'without products' do
    it do
      expect(subject).to eq(
        {
          data: {
            id: taxon.id.to_s,
            type: :taxon,
            attributes: {
              position: taxon.position,
              name: taxon.name,
              permalink: taxon.permalink,
              lft: taxon.lft,
              rgt: taxon.rgt,
              description: taxon.description,
              created_at: taxon.created_at,
              updated_at: taxon.updated_at,
              meta_title: taxon.meta_title,
              meta_description: taxon.meta_description,
              meta_keywords: taxon.meta_keywords,
              depth: taxon.depth,
              pretty_name: taxon.pretty_name,
              seo_title: taxon.seo_title,
              is_root: taxon.root?,
              is_child: taxon.child?,
              is_leaf: taxon.leaf?,
              public_metadata: {},
              private_metadata: {}
            },
            relationships: {
              parent: {
                data: {
                  id: taxon.parent.id.to_s,
                  type: :taxon
                }
              },
              taxonomy: {
                data: {
                  id: taxon.taxonomy.id.to_s,
                  type: :taxonomy
                }
              },
              image: {
                data: {
                  id: taxon.icon.id.to_s,
                  type: :taxon_image
                }
              },
              children: {
                data: [
                  {
                    id: taxon.children.first.id.to_s,
                    type: :taxon
                  },
                  {
                    id: taxon.children.second.id.to_s,
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

  context 'with products' do
    before do
      serializer_params[:include_products] = true
    end

    it do
      expect(subject).to eq(
        {
          data: {
            id: taxon.id.to_s,
            type: :taxon,
            attributes: {
              position: taxon.position,
              name: taxon.name,
              permalink: taxon.permalink,
              lft: taxon.lft,
              rgt: taxon.rgt,
              description: taxon.description,
              created_at: taxon.created_at,
              updated_at: taxon.updated_at,
              meta_title: taxon.meta_title,
              meta_description: taxon.meta_description,
              meta_keywords: taxon.meta_keywords,
              depth: taxon.depth,
              pretty_name: taxon.pretty_name,
              seo_title: taxon.seo_title,
              is_root: taxon.root?,
              is_child: taxon.child?,
              is_leaf: taxon.leaf?,
              public_metadata: {},
              private_metadata: {}
            },
            relationships: {
              parent: {
                data: {
                  id: taxon.parent.id.to_s,
                  type: :taxon
                }
              },
              taxonomy: {
                data: {
                  id: taxon.taxonomy.id.to_s,
                  type: :taxonomy
                }
              },
              image: {
                data: {
                  id: taxon.icon.id.to_s,
                  type: :taxon_image
                }
              },
              products: {
                data: [
                  {
                    id: taxon.products.first.id.to_s,
                    type: :product
                  },
                  {
                    id: taxon.products.second.id.to_s,
                    type: :product
                  }
                ]
              },
              children: {
                data: [
                  {
                    id: taxon.children.first.id.to_s,
                    type: :taxon
                  },
                  {
                    id: taxon.children.second.id.to_s,
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

  it_behaves_like 'an ActiveJob serializable hash'
end
