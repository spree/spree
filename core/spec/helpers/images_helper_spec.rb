require 'spec_helper'

describe Spree::ImagesHelper, type: :helper do
  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:image) do
    product_image = create(:image, viewable: product)
    product_image.attachment.attach(
      io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
      filename: 'thinking-cat.jpg',
      content_type: 'image/jpeg'
    )
    product_image
  end
  let(:attachment) { image.attachment }

  describe '#spree_image_tag' do
    it 'returns an image tag with the correct url' do
      expect(helper).to receive(:spree_image_url).with(image, { width: 100, height: 100, format: nil }).and_return('image_url')
      expect(helper).to receive(:image_tag).with('image_url', { width: 100, height: 100 }).and_return('image_tag')
      expect(helper.spree_image_tag(image, width: 100, height: 100)).to eq('image_tag')
    end
  end

  describe '#spree_image_url' do
    it 'supports blob' do
      expect(helper.spree_image_url(image.blob)).to eq(helper.spree_image_url(image))
    end

    context 'when image is not attached' do
      before do
        allow(image).to receive(:attached?).and_return(false)
      end

      it 'returns nil' do
        expect(helper.spree_image_url(image)).to be_nil
      end
    end

    context 'when image is not variable' do
      before do
        allow(image).to receive_messages(attached?: true, variable?: false)
      end

      it 'returns nil' do
        expect(helper.spree_image_url(image)).to be_nil
      end
    end

    context 'when width and height are present' do
      it 'returns a url with resize_to_fill' do
        variant = double('variant')
        expect(image).to receive(:variant).with(hash_including(resize_to_fill: [200, 200])).and_return(variant)
        expect(Rails.application.routes.url_helpers).to receive(:cdn_image_url).and_return('cdn_url')
        expect(helper.spree_image_url(image, width: 100, height: 100)).to eq('cdn_url')
      end
    end

    context 'when only width is present' do
      it 'returns a url with resize_to_limit' do
        variant = double('variant')
        expect(image).to receive(:variant).with(hash_including(resize_to_limit: [200, nil])).and_return(variant)
        expect(Rails.application.routes.url_helpers).to receive(:cdn_image_url).and_return('cdn_url')
        expect(helper.spree_image_url(image, width: 100)).to eq('cdn_url')
      end
    end

    context 'when format is provided' do
      it 'returns a url with the correct format' do
        variant = double('variant')
        expect(image).to receive(:variant).with(hash_including(resize_to_fill: [200, 200], format: :png)).and_return(variant)
        expect(Rails.application.routes.url_helpers).to receive(:cdn_image_url).and_return('cdn_url')
        expect(helper.spree_image_url(image, width: 100, height: 100, format: :png)).to eq('cdn_url')
      end
    end
  end

  describe '#spree_asset_aspect_ratio' do
    context 'when attachment is not present' do
      it 'returns nil' do
        expect(helper.spree_asset_aspect_ratio(nil)).to be_nil
      end
    end

    context 'when attachment is not analyzed' do
      before do
        allow(attachment).to receive(:analyzed?).and_return(false)
      end

      it 'returns nil' do
        expect(helper.spree_asset_aspect_ratio(attachment)).to be_nil
      end
    end

    context 'when aspect_ratio is present in metadata' do
      before do
        allow(attachment).to receive_messages(analyzed?: true, metadata: { 'aspect_ratio' => 1.5 })
      end

      it 'returns the aspect ratio' do
        expect(helper.spree_asset_aspect_ratio(attachment)).to eq(1.5)
      end
    end

    context 'when calculating aspect ratio from dimensions' do
      before do
        allow(attachment).to receive_messages(analyzed?: true, metadata: { 'width' => width, 'height' => height })
      end

      context 'when height is greater than width' do
        let(:width) { 100 }
        let(:height) { 200 }

        it 'returns the correct ratio' do
          expect(helper.spree_asset_aspect_ratio(attachment)).to eq(2.0)
        end
      end

      context 'when width is greater than height' do
        let(:width) { 200 }
        let(:height) { 100 }

        it 'returns the correct ratio' do
          expect(helper.spree_asset_aspect_ratio(attachment)).to eq(2.0)
        end
      end

      context 'when width equals height' do
        let(:width) { 100 }
        let(:height) { 100 }

        it 'returns 1.0' do
          expect(helper.spree_asset_aspect_ratio(attachment)).to eq(1.0)
        end
      end
    end
  end
end
