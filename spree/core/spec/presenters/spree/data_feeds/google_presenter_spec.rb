require 'spec_helper'

RSpec.describe Spree::DataFeeds::GooglePresenter do
  let(:store) { @default_store }
  let(:data_feed) { create(:google_data_feed, store: store) }
  let(:product) { create(:product, stores: [store]) }
  let!(:variant) { create(:with_image_variant, product: product) }

  subject { described_class.new(data_feed) }

  describe '#call' do
    let(:xml) { subject.call }

    context 'store information' do
      it 'includes store name' do
        expect(xml).to include("<title>#{store.name}</title>")
      end

      it 'includes store url' do
        expect(xml).to include("<link>#{store.url}</link>")
      end

      it 'includes store description' do
        expect(xml).to include("<description>#{store.meta_description}</description>")
      end
    end

    context 'required attributes' do
      it 'includes variant id' do
        expect(xml).to include("<g:id>#{variant.id}</g:id>")
      end

      it 'includes product id as item_group_id' do
        expect(xml).to include("<g:item_group_id>#{product.id}</g:item_group_id>")
      end

      it 'includes title with variant option values' do
        expect(xml).to include("<g:title>#{product.name} - #{variant.option_values.first.name}</g:title>")
      end

      it 'includes description' do
        expect(xml).to include("<g:description>#{product.description}</g:description>")
      end

      it 'includes link' do
        expect(xml).to include("<g:link>#{store.url}/products/#{product.slug}</g:link>")
      end

      it 'includes image link' do
        image = variant.images.first
        expected_url = Rails.application.routes.url_helpers.cdn_image_url(image.attachment.variant(:xlarge))
        expect(xml).to include("<g:image_link>#{expected_url}</g:image_link>")
      end

      it 'includes price' do
        expect(xml).to include("<g:price>#{variant.price} #{variant.cost_currency}</g:price>")
      end
    end

    context 'availability' do
      it 'shows in stock for available products' do
        expect(xml).to include('<g:availability>in stock</g:availability>')
      end

      it 'includes availability date' do
        expect(xml).to include("<g:availability_date>#{product.available_on.xmlschema}</g:availability_date>")
      end

      context 'when product is set to backorderable' do
        let(:product) { create(:product, stores: [store], available_on: 1.year.from_now) }

        it 'shows backorder' do
          expect(xml).to include('<g:availability>backorder</g:availability>')
        end
      end

      context 'when availability date is nil' do
        let(:product) { create(:product, stores: [store], available_on: nil) }

        it 'shows in stock' do
          expect(xml).to include('<g:availability>in stock</g:availability>')
        end

        it 'does not include availability date' do
          expect(xml).not_to include('<g:availability_date>')
        end
      end
    end

    context 'product with only master variant' do
      let(:product) { create(:product, stores: [store]) }
      let!(:variant) { nil }

      before do
        product.master.images << create(:image)
      end

      it 'includes master variant in feed' do
        expect(xml).to include("<g:id>#{product.master.id}</g:id>")
      end

      it 'includes product name as title' do
        expect(xml).to include("<g:title>#{product.name}</g:title>")
      end
    end

    context 'optional attributes from product properties' do
      let(:product) { create(:product_with_properties, stores: [store]) }

      it 'includes product properties' do
        expect(xml).to include("<g:brand>#{product.property('brand')}</g:brand>")
      end
    end

    context 'title generation does not mutate product name' do
      it 'generates independent titles for multiple variants' do
        option_type = create(:option_type)
        option_a = create(:option_value, name: 'option-a', option_type: option_type)
        option_b = create(:option_value, name: 'option-b', option_type: option_type)

        create(:with_image_variant, product: product, option_values: [option_a])
        create(:with_image_variant, product: product, option_values: [option_b])

        expect(xml).to include("#{product.name} - option-a</g:title>")
        expect(xml).to include("#{product.name} - option-b</g:title>")
        expect(xml).not_to include('option-a - option-b')
      end
    end
  end
end
