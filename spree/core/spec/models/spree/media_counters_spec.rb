require 'spec_helper'

describe Spree::Media, type: :model do
  let(:media) { described_class.new }
  let(:image_file) { File.open("#{Spree::Core::Engine.root}/spec/fixtures/thinking-cat.jpg") }
  let(:text_file) { File.open("#{Spree::Core::Engine.root}/spec/fixtures/text-file.txt") }

  context 'validation' do
    it 'has attachment present' do
      media.attachment.attach(io: image_file, filename: 'thinking-cat.jpg')
      expect(media).to be_valid
    end

    it 'has attachment absent' do
      media.attachment.attach(nil)
      expect(media).not_to be_valid
    end

    it 'allows only web image content types' do
      media.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      expect(media).to be_valid
    end

    it 'does not allow non-web image content types' do
      media.attachment.attach(io: text_file, filename: 'text-file.txt', content_type: 'text/plain')
      expect(media).not_to be_valid
    end
  end

  context 'cache expiration' do
    let!(:image) { create(:image, position: 1, viewable: viewable) }
    let!(:image_2) { create(:image, position: 2, viewable: viewable) }

    describe 'update position' do
      let(:product) { create(:product) }
      let!(:variants) { create_list(:variant, 2, product: product) }

      context 'when viewable is a product-level asset' do
        let(:viewable) { product }

        it 'touches product variants' do
          image.viewable.reload
          expect(image).to receive(:touch_product_variants)
          image.set_list_position(2)
        end
      end

      context 'when viewable is a variant' do
        let(:viewable) { variants.first }

        it 'does not touch product variants' do
          expect(image).not_to receive(:touch_product_variants)
          image.set_list_position(2)
        end
      end
    end
  end

  describe 'media_count counter cache' do
    let(:variant) { create(:variant) }

    it 'increments media_count when image is created' do
      expect { create(:image, viewable: variant) }.to change { variant.reload.media_count }.by(1)
    end

    it 'decrements media_count when image is destroyed' do
      image = create(:image, viewable: variant)
      expect { image.destroy }.to change { variant.reload.media_count }.by(-1)
    end

    it 'tracks multiple images correctly' do
      expect(variant.media_count).to eq(0)
      create(:image, viewable: variant)
      create(:image, viewable: variant)
      expect(variant.reload.media_count).to eq(2)
    end
  end

  describe 'product media_count counter cache' do
    let(:product) { create(:product) }
    let(:variant) { create(:variant, product: product) }

    it 'increments media_count when image is created on the default variant' do
      expect { create(:image, viewable: product.default_variant) }.to change { product.reload.media_count }.by(1)
    end

    it 'increments media_count when image is created on variant' do
      expect { create(:image, viewable: variant) }.to change { product.reload.media_count }.by(1)
    end

    it 'decrements media_count when image is destroyed' do
      image = create(:image, viewable: variant)
      expect { image.destroy }.to change { product.reload.media_count }.by(-1)
    end

    it 'tracks media across all variants correctly' do
      expect(product.media_count).to eq(0)
      create(:image, viewable: product.default_variant)
      create(:image, viewable: variant)
      create(:image, viewable: variant)
      expect(product.reload.media_count).to eq(3)
    end
  end

  describe 'thumbnail choice with video in the gallery' do
    let(:product) { create(:product) }

    it 'skips a leading video that has no still' do
      video = create(:video_asset, viewable: product, position: 1)
      image = create(:image, viewable: product, position: 2)

      product.update_thumbnail!

      expect(product.reload.primary_media_id).to eq(image.id)
      expect(video.renderable_as_image?).to be(false)
    end

    it 'uses a leading video once it has a still' do
      video = create(:external_video_asset, viewable: product, position: 1)
      create(:image, viewable: product, position: 2)

      product.update_thumbnail!

      # A YouTube link carries the provider's own thumbnail, so it can lead.
      expect(product.reload.primary_media_id).to eq(video.id)
    end
  end

  describe 'media_count when a row changes owner' do
    let(:product) { create(:product) }
    let(:other_product) { create(:product) }

    it 'clears the old owner thumbnail, which still pointed at the moved row' do
      media = create(:image, viewable: product)
      expect(product.reload.primary_media_id).to eq(media.id)

      media.update!(viewable: other_product)

      expect(product.reload.primary_media_id).to be_nil
      expect(other_product.reload.primary_media_id).to eq(media.id)
    end

    it 'treats a type-only change as a move' do
      variant = create(:variant, product: product)
      media = create(:image, viewable: variant)

      # Same numeric id on both sides, so only viewable_type changes. Watching
      # viewable_id alone would sit this move out and leave both owners wrong.
      Spree::Media.where(id: media.id).update_all(viewable_id: product.id)
      media.reload
      media.update!(viewable_type: 'Spree::Product')

      expect(media.send(:saved_change_to_viewable?)).to be(true)
      expect(media.reload.viewable).to eq(product)
    end

    it 'moves the count from the old owner to the new one' do
      media = create(:image, viewable: product)
      expect(product.reload.media_count).to eq(1)

      media.update!(viewable: other_product)

      expect(product.reload.media_count).to eq(0)
      expect(other_product.reload.media_count).to eq(1)
    end
  end

  describe 'primary_media_id updates' do
    let(:product) { create(:product) }
    let(:variant) { product.default_variant }

    it 'sets variant primary_media_id when first image is created' do
      expect(variant.primary_media_id).to be_nil
      image = create(:image, viewable: variant)
      expect(variant.reload.primary_media_id).to eq(image.id)
    end

    it 'sets product primary_media_id when first image is created' do
      expect(product.primary_media_id).to be_nil
      image = create(:image, viewable: variant)
      expect(product.reload.primary_media_id).to eq(image.id)
    end

    it 'updates primary_media_id when first image is destroyed' do
      image1 = create(:image, viewable: variant, position: 1)
      image2 = create(:image, viewable: variant, position: 2)
      expect(variant.reload.primary_media_id).to eq(image1.id)

      image1.destroy
      expect(variant.reload.primary_media_id).to eq(image2.id)
    end

    it 'sets primary_media_id to nil when last image is destroyed' do
      image = create(:image, viewable: variant)
      expect(variant.reload.primary_media_id).to eq(image.id)

      image.destroy
      expect(variant.reload.primary_media_id).to be_nil
    end

    it 'updates primary_media_id when image position changes' do
      image1 = create(:image, viewable: variant, position: 1)
      image2 = create(:image, viewable: variant, position: 2)
      expect(variant.reload.primary_media_id).to eq(image1.id)

      image2.update!(position: 0)
      expect(variant.reload.primary_media_id).to eq(image2.id)
    end
  end
end
