require 'spec_helper'

describe Spree::V2::Storefront::TaxonSerializer do
  subject { described_class.new(taxon, params: serializer_params).serializable_hash }

  include_context 'API v2 serializers params'

  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:taxon) { create(:taxon, :with_description, taxonomy: taxonomy, products: build_list(:product, 2, stores: [store])) }
  let!(:children) { create_list(:taxon, 2, taxonomy: taxonomy, parent: taxon) }
  let(:url_helpers) { Rails.application.routes.url_helpers }

  let!(:metafield_definition) { create(:metafield_definition, :short_text_field, resource_type: 'Spree::Taxon') }
  let!(:metafield) { create(:metafield, metafield_definition: metafield_definition, resource: taxon, value: 'Additional Info') }

  before do
    taxon.reload # Reload taxon to ensure all associations are loaded
  end

  context 'without products' do
    it do
      expect(subject).to match(
        {
          data: {
            id: taxon.id.to_s,
            type: :taxon,
            attributes: {
              name: taxon.name,
              pretty_name: taxon.pretty_name,
              permalink: taxon.permalink,
              seo_title: taxon.seo_title,
              meta_title: taxon.meta_title,
              meta_description: taxon.meta_description,
              meta_keywords: taxon.meta_keywords,
              left: taxon.left,
              right: taxon.right,
              position: taxon.position,
              depth: taxon.depth,
              updated_at: taxon.updated_at,
              public_metadata: {},
              description: taxon.description.to_plain_text,
              has_products: taxon.active_products_with_descendants.exists?,
              header_url: nil,
              is_root: taxon.root?,
              is_child: taxon.child?,
              is_leaf: taxon.leaf?,
              localized_slugs: taxon.localized_slugs_for_store(store)
            },
            relationships: {
              parent: {
                data: {
                  id: taxon.parent_id.to_s,
                  type: :taxon
                }
              },
              taxonomy: {
                data: {
                  id: taxonomy.id.to_s,
                  type: :taxonomy
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
              },
              image: {
                data: nil
              },
              metafields: {
                data: [
                  {
                    id: metafield.id.to_s,
                    type: :metafield
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
      expect(subject).to match(
        {
          data: {
            id: taxon.id.to_s,
            type: :taxon,
            attributes: {
              name: taxon.name,
              pretty_name: taxon.pretty_name,
              permalink: taxon.permalink,
              seo_title: taxon.seo_title,
              meta_title: taxon.meta_title,
              meta_description: taxon.meta_description,
              meta_keywords: taxon.meta_keywords,
              left: taxon.left,
              right: taxon.right,
              position: taxon.position,
              depth: taxon.depth,
              updated_at: taxon.updated_at,
              public_metadata: {},
              description: taxon.description.to_plain_text,
              has_products: taxon.active_products_with_descendants.exists?,
              header_url: nil,
              is_root: taxon.root?,
              is_child: taxon.child?,
              is_leaf: taxon.leaf?,
              localized_slugs: taxon.localized_slugs_for_store(store)
            },
            relationships: {
              parent: {
                data: {
                  id: taxon.parent_id.to_s,
                  type: :taxon
                }
              },
              taxonomy: {
                data: {
                  id: taxonomy.id.to_s,
                  type: :taxonomy
                }
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
              image: {
                data: nil
              },
              metafields: {
                data: [
                  {
                    id: metafield.id.to_s,
                    type: :metafield
                  }
                ]
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
end
