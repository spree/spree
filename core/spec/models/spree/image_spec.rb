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

    it 'has allowed attachment content type' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      expect(spree_image).to be_valid
    end

    it 'has no allowed attachment content type' do
      spree_image.attachment.attach(io: text_file, filename: 'text-file.txt', content_type: 'text/plain')
      expect(spree_image).not_to be_valid
    end
  end

  describe '#styles' do
    it 'will return all styles for the image' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      res = spree_image.styles

      expect(res.length).to eq described_class.styles.keys.length
    end
  end

  describe '#style' do
    it 'will return style for the given name' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      styles = described_class.styles.keys
      random_style_name = styles.sample
      res = spree_image.style(random_style_name)

      expect(res[:size]).to eq described_class.styles[random_style_name]
    end
  end
end
