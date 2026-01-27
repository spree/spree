require 'spec_helper'

describe Spree::Api::V2::Platform::TaxonSerializer do
  subject { described_class.new(taxon.reload, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:taxon) { create(:taxon, :with_description, taxonomy: taxonomy, products: create_list(:product, 2, stores: [store])) }
  let!(:children) { create_list(:taxon, 2, taxonomy: taxonomy, parent: taxon) }
  let(:url_helpers) { Rails.application.routes.url_helpers }

  context 'without products' do
    it do
      expect(subject).to match(
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
              description: taxon.description.to_plain_text,
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
              automatic: taxon.automatic?,
              sort_order: taxon.sort_order,
              rules_match_policy: taxon.rules_match_policy,
              header_url: nil,
              public_metadata: {},
              private_metadata: {},
              children_count: taxon.children_count,
              classification_count: taxon.classification_count
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
                data: nil
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
              },
              metafields: {
                data: []
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
      expect(subject).to match(
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
              description: taxon.description.to_plain_text,
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
              automatic: taxon.automatic?,
              sort_order: taxon.sort_order,
              rules_match_policy: taxon.rules_match_policy,
              header_url: nil,
              public_metadata: {},
              private_metadata: {},
              children_count: taxon.children_count,
              classification_count: taxon.classification_count
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
                data: nil
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
                data: contain_exactly(
                  {
                    id: taxon.children.first.id.to_s,
                    type: :taxon
                  },
                  {
                    id: taxon.children.second.id.to_s,
                    type: :taxon
                  }
                )
              },
              metafields: {
                data: []
              }
            }
          }
        }
      )
    end
  end

  context 'with header image' do
    let(:taxon) { create(:taxon, :with_header_image, taxonomy: taxonomy) }

    it do
      expect(subject[:data][:attributes][:header_url]).to eq(url_helpers.cdn_image_url(taxon.image.attachment))
    end
  end

  it_behaves_like 'an ActiveJob serializable hash'
end
