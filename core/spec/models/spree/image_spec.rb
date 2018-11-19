require 'spec_helper'

describe Spree::Image, type: :model do
  context 'validation' do
    let(:spree_image) { Spree::Image.new }
    let(:image_file) { File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg') }
    let(:text_file) { File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'text-file.txt') }

    it 'has attachment present' do
      if Rails.application.config.use_paperclip
        spree_image.attachment = image_file
      else
        spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg')
      end
      expect(spree_image).to be_valid
    end

    it 'has attachment absent' do
      if Rails.application.config.use_paperclip
        spree_image.attachment = nil
      else
        spree_image.attachment.attach(nil)
      end
      expect(spree_image).not_to be_valid
    end

    it 'has allowed attachment content type' do
      if Rails.application.config.use_paperclip
        spree_image.attachment = image_file
      else
        spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      end
      expect(spree_image).to be_valid
    end

    it 'has no allowed attachment content type' do
      if Rails.application.config.use_paperclip
        spree_image.attachment = text_file
      else
        spree_image.attachment.attach(io: text_file, filename: 'text-file.txt', content_type: 'text/plain')
      end
      expect(spree_image).not_to be_valid
    end
  end
end
