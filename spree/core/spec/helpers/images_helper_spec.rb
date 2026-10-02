require 'spec_helper'

describe Spree::ImagesHelper, type: :helper do
  let(:store) { @default_store }
  let(:product) { create(:product) }
  let(:image) do
    product_image = create(:image, viewable: product)
    product_image.attachment.attach(
      io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
      filename: 'thinking-cat.jpg',
      content_type: 'image/jpeg'
    )
    product_image
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
        expect(image).to receive(:variant).with(hash_including(resize_to_fill: [200, 200], format: "png")).and_return(variant)
        expect(Rails.application.routes.url_helpers).to receive(:cdn_image_url).and_return('cdn_url')
        expect(helper.spree_image_url(image, width: 100, height: 100, format: :png)).to eq('cdn_url')
      end
    end

    context 'when variant option is provided' do
      it 'uses the named variant directly' do
        variant = double('variant')
        expect(image).to receive(:variant).with(:mini).and_return(variant)
        expect(Rails.application.routes.url_helpers).to receive(:cdn_image_url).and_return('cdn_url')
        expect(helper.spree_image_url(image, variant: :mini)).to eq('cdn_url')
      end

      it 'ignores width and height when variant is provided' do
        variant = double('variant')
        expect(image).to receive(:variant).with(:small).and_return(variant)
        expect(Rails.application.routes.url_helpers).to receive(:cdn_image_url).and_return('cdn_url')
        expect(helper.spree_image_url(image, variant: :small, width: 100, height: 100)).to eq('cdn_url')
      end
    end
  end
end
