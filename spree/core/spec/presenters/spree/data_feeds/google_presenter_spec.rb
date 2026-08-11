require 'spec_helper'

RSpec.describe Spree::DataFeeds::GooglePresenter do
  let(:store) { @default_store }
  let(:data_feed) { create(:google_data_feed, store: store) }
  let(:product) { create(:product, available_on: Date.current) }
  let!(:variant) { create(:with_image_variant, product: product) }

  subject { described_class.new(data_feed) }

  describe '#call' do
    let(:xml) { subject.call }

    context 'store information' do
      it 'includes store name' do
        expect(xml).to include("<title>#{store.name}</title>")
      end

      it 'includes store url' do
        expect(xml).to include("<link>#{store.storefront_url}</link>")
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
        expect(xml).to include("<g:description>#{Spree::RichTextHelper.to_plain_text(product.description)}</g:description>")
      end

      it 'strips markup from the description, since Google expects plain text' do
        product.update!(description: '<p>Soft cotton.</p><p>Machine <strong>washable</strong>.</p>')

        expect(xml).to include('<g:description>Soft cotton.
Machine washable.</g:description>')
      end

      it 'includes link' do
        expect(xml).to include("<g:link>#{store.storefront_url}/products/#{product.slug}</g:link>")
      end

      it 'includes image link' do
        image = variant.images.first
        expected_url = Rails.application.routes.url_helpers.cdn_image_url(image.attachment.variant(:xlarge))
        expect(xml).to include("<g:image_link>#{expected_url}</g:image_link>")
      end

      it 'includes price' do
        expect(xml).to include("<g:price>#{variant.amount_in(store.default_currency)} #{store.default_currency}</g:price>")
      end

      # The variant's own cost_currency is unrelated to the currency the feed
      # quotes in, and may carry no price at all.
      context "when the variant's cost_currency differs from the store currency" do
        before { variant.update!(cost_currency: 'JPY') }

        it 'quotes the price in the store currency' do
          expect(xml).to include("<g:price>#{variant.amount_in(store.default_currency)} #{store.default_currency}</g:price>")
        end

        it 'emits no empty price' do
          expect(xml).not_to include('<g:price> ')
          expect(xml).not_to include('<g:price>JPY</g:price>')
        end
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
        let(:product) { create(:product, available_on: 1.year.from_now) }

        it 'shows backorder' do
          expect(xml).to include('<g:availability>backorder</g:availability>')
        end
      end

      context 'when availability date is nil' do
        let(:product) { create(:product, available_on: nil) }

        it 'shows in stock' do
          expect(xml).to include('<g:availability>in stock</g:availability>')
        end

        it 'does not include availability date' do
          expect(xml).not_to include('<g:availability_date>')
        end
      end
    end

    context 'product with only default variant' do
      let(:product) { create(:product) }
      let!(:variant) { nil }

      before do
        product.default_variant.images << create(:image)
      end

      it 'includes default variant in feed' do
        expect(xml).to include("<g:id>#{product.default_variant.id}</g:id>")
      end

      it 'includes product name as title' do
        expect(xml).to include("<g:title>#{product.name}</g:title>")
      end
    end

    context 'optional attributes from product custom_fields' do
      let(:product) { create(:product) }
      let(:custom_field_definition) { create(:custom_field_definition, label: 'Brand', key: 'brand') }
      let!(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'Nike') }

      it 'includes product custom_fields' do
        expect(xml).to include("<g:brand>#{product.custom_fields.first.value}</g:brand>")
      end
    end

    context 'custom_field with a key that is not a known Google attribute' do
      let(:product) { create(:product) }
      let(:custom_field_definition) { create(:custom_field_definition, label: 'Internal', key: 'internal_note') }
      let!(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'secret') }

      it 'omits the custom_field from the feed' do
        expect(xml).not_to include('internal_note')
        expect(xml).not_to include('secret')
      end
    end

    context 'custom_field whose key collides with a Ruby method name' do
      let(:product) { create(:product) }
      let(:custom_field_definition) do
        create(:custom_field_definition, label: 'System', key: 'brand').tap do |definition|
          definition.update_column(:key, 'system')
        end
      end
      let!(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'id') }

      it 'does not dispatch the key as a method and omits it from the feed' do
        expect(xml).not_to include('<g:system>')
      end
    end

    context 'custom_field whose key matches a required attribute' do
      let(:product) { create(:product) }
      let(:custom_field_definition) { create(:custom_field_definition, label: 'Item Group', key: 'item_group_id') }
      let!(:custom_field) { create(:custom_field, resource: product, custom_field_definition: custom_field_definition, value: 'injected') }

      it 'does not emit the custom_field value, only the required item_group_id' do
        expect(xml).to include("<g:item_group_id>#{product.id}</g:item_group_id>")
        expect(xml).not_to include('<g:item_group_id>injected</g:item_group_id>')
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
