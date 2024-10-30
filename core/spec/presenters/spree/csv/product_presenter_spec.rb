require 'spec_helper'

describe Spree::CSV::ProductPresenter do
  describe '#call' do
    subject(:presentation) { described_class.new(product, properties).call }

    let(:store) { Spree::Store.default }
    let(:brand_taxonomy) { store.taxonomies.find_by(name: Spree.t(:taxonomy_brands_name)) || create(:taxonomy, name: Spree.t(:taxonomy_brands_name), store: store) }
    let(:brand) { create(:taxon, taxonomy: brand_taxonomy, name: 'Super seller') }
    let(:property) { create(:property, :material) }
    let(:product) do
      create(:product,
             product_properties: [create(:product_property, property: property, value: 'Cotton')],
             taxons: [brand])
    end

    let(:properties) { [property] }

    before(:each) do
      product.update(available_on: Time.current, weight: 77, width: 777)
      product.label_list.add('label1', 'label2')
      product.tag_list.add('tag1', 'tag2')
      product.save!
    end

    it 'presents product with properties' do
      product.reload

      expect(presentation.length).to eq(24)

      expect(presentation[0]).to eq(product.id)
      expect(presentation[2]).to eq(product.brand.name)
      expect(presentation[3]).to eq(product.name)
      expect(presentation[4]).to eq(product.description)
      expect(presentation[5]).to eq(product.price.to_f)
      expect(presentation[6]).to eq(product.meta_title)
      expect(presentation[7]).to eq(product.meta_description)
      expect(presentation[8]).to eq(product.meta_keywords)
      expect(presentation[9].to_s).to eq(product.tag_list.to_s)
      expect(presentation[10].to_s).to eq(product.label_list.to_s)
      expect(presentation[11]).to eq(product.width)
      expect(presentation[12]).to eq(product.height)
      expect(presentation[13]).to eq(product.depth)
      expect(presentation[14]).to eq(product.weight)
      expect(presentation[15]).to eq(product.available_on.strftime('%Y-%m-%d %H:%M:%S'))
      expect(presentation[16]).to eq(product.discontinue_on)
      expect(presentation[17]).to eq(product.status)
      expect(presentation[18]).to eq('Brands -> Super seller')
      expect(presentation[19]).to eq(nil)
      expect(presentation[20]).to eq(nil)
      expect(presentation[21]).to eq(0)
      expect(presentation[22]).to eq(property.name)
      expect(presentation[23]).to eq(product.property(property.name))
    end

    context 'when providing more properties' do
      let(:property_2) { create(:property, :manufacturer) }
      let(:property_3) { create(:property, :brand) }

      let(:properties) { [property, property_2, property_3] }

      before do
        product.product_properties << create(:product_property, property: property_2, value: 'Global manufacturer')
        product.product_properties << create(:product_property, property: property_3, value: 'Global brand')
      end

      it 'presents product with properties' do
        product.reload

        expect(presentation.length).to eq(28)

        expect(presentation[0]).to eq(product.id)
        expect(presentation[2]).to eq(product.brand.name)
        expect(presentation[3]).to eq(product.name)
        expect(presentation[4]).to eq(product.description)
        expect(presentation[5]).to eq(product.price.to_f)
        expect(presentation[6]).to eq(product.meta_title)
        expect(presentation[7]).to eq(product.meta_description)
        expect(presentation[8]).to eq(product.meta_keywords)
        expect(presentation[9].to_s).to eq(product.tag_list.to_s)
        expect(presentation[10].to_s).to eq(product.label_list.to_s)
        expect(presentation[11]).to eq(product.width)
        expect(presentation[12]).to eq(product.height)
        expect(presentation[13]).to eq(product.depth)
        expect(presentation[14]).to eq(product.weight)
        expect(presentation[15]).to eq(product.available_on.strftime('%Y-%m-%d %H:%M:%S'))
        expect(presentation[16]).to eq(product.discontinue_on)
        expect(presentation[17]).to eq(product.status)
        expect(presentation[18]).to eq('Brands -> Super seller')
        expect(presentation[19]).to eq(nil)
        expect(presentation[20]).to eq(nil)
        expect(presentation[21]).to eq(0)
        expect(presentation[22]).to eq('material')
        expect(presentation[23]).to eq('Cotton')
        expect(presentation[24]).to eq('manufacturer')
        expect(presentation[25]).to eq('Global manufacturer')
        expect(presentation[26]).to eq('brand')
        expect(presentation[27]).to eq('Global brand')
      end
    end
  end
end
