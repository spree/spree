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
end
