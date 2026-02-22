require 'spec_helper'

describe Spree::Image, type: :model do
  let(:spree_image) { described_class.new }
  let(:image_file) { File.open("#{Spree::Core::Engine.root}/spec/fixtures/thinking-cat.jpg") }
  let(:text_file) { File.open("#{Spree::Core::Engine.root}/spec/fixtures/text-file.txt") }

  context 'validation' do
    it 'has attachment present' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg')
      expect(spree_image).to be_valid
    end

    it 'has attachment absent' do
      spree_image.attachment.attach(nil)
      expect(spree_image).not_to be_valid
    end

    it 'allows only web image content types' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      expect(spree_image).to be_valid
    end

    it 'does not allow non-web image content types' do
      spree_image.attachment.attach(io: text_file, filename: 'text-file.txt', content_type: 'text/plain')
      expect(spree_image).not_to be_valid
    end
  end

  describe '#styles' do
    it 'will return all styles for the image' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      spree_image.save!
      res = spree_image.styles

      expect(res.length).to eq described_class.styles.keys.length
    end
  end

  describe '#style' do
    it 'will return style for the given name' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      spree_image.save!
      styles = described_class.styles.keys
      random_style_name = styles.sample
      res = spree_image.style(random_style_name)

      expect(res[:size]).to eq described_class.styles[random_style_name]
    end
  end

  context 'cache expiration' do
    let!(:image) { create(:image, position: 1, viewable: viewable) }
    let!(:image_2) { create(:image, position: 2, viewable: viewable) }

    describe 'update position' do
      let(:product) { create(:product) }
      let!(:variants) { create_list(:variant, 2, product: product) }

      context 'when viewable is a master variant' do
        let(:viewable) { product.reload.master }

        it 'touches product variants' do
          image.viewable.product.reload
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

  describe 'image_count counter cache' do
    let(:variant) { create(:variant) }

    it 'increments image_count when image is created' do
      expect { create(:image, viewable: variant) }.to change { variant.reload.image_count }.by(1)
    end

    it 'decrements image_count when image is destroyed' do
      image = create(:image, viewable: variant)
      expect { image.destroy }.to change { variant.reload.image_count }.by(-1)
    end

    it 'tracks multiple images correctly' do
      expect(variant.image_count).to eq(0)
      create(:image, viewable: variant)
      create(:image, viewable: variant)
      expect(variant.reload.image_count).to eq(2)
    end
  end

  describe 'total_image_count counter cache on product' do
    let(:product) { create(:product) }
    let(:variant) { create(:variant, product: product) }

    it 'increments total_image_count when image is created on master' do
      expect { create(:image, viewable: product.master) }.to change { product.reload.total_image_count }.by(1)
    end

    it 'increments total_image_count when image is created on variant' do
      expect { create(:image, viewable: variant) }.to change { product.reload.total_image_count }.by(1)
    end

    it 'decrements total_image_count when image is destroyed' do
      image = create(:image, viewable: variant)
      expect { image.destroy }.to change { product.reload.total_image_count }.by(-1)
    end

    it 'tracks images across all variants correctly' do
      expect(product.total_image_count).to eq(0)
      create(:image, viewable: product.master)
      create(:image, viewable: variant)
      create(:image, viewable: variant)
      expect(product.reload.total_image_count).to eq(3)
    end
  end

  describe 'thumbnail_id updates' do
    let(:product) { create(:product) }
    let(:variant) { product.master }

    it 'sets variant thumbnail_id when first image is created' do
      expect(variant.thumbnail_id).to be_nil
      image = create(:image, viewable: variant)
      expect(variant.reload.thumbnail_id).to eq(image.id)
    end

    it 'sets product thumbnail_id when first image is created' do
      expect(product.thumbnail_id).to be_nil
      image = create(:image, viewable: variant)
      expect(product.reload.thumbnail_id).to eq(image.id)
    end

    it 'updates thumbnail_id when first image is destroyed' do
      image1 = create(:image, viewable: variant, position: 1)
      image2 = create(:image, viewable: variant, position: 2)
      expect(variant.reload.thumbnail_id).to eq(image1.id)

      image1.destroy
      expect(variant.reload.thumbnail_id).to eq(image2.id)
    end

    it 'sets thumbnail_id to nil when last image is destroyed' do
      image = create(:image, viewable: variant)
      expect(variant.reload.thumbnail_id).to eq(image.id)

      image.destroy
      expect(variant.reload.thumbnail_id).to be_nil
    end

    it 'updates thumbnail_id when image position changes' do
      image1 = create(:image, viewable: variant, position: 1)
      image2 = create(:image, viewable: variant, position: 2)
      expect(variant.reload.thumbnail_id).to eq(image1.id)

      image2.update!(position: 0)
      expect(variant.reload.thumbnail_id).to eq(image2.id)
    end
  end
end
