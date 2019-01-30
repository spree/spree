require 'spec_helper'

describe Spree::TaxonImage, type: :model do
  context 'validation' do
    let(:spree_image) { Spree::TaxonImage.new }
    let(:image_file) { File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg') }
    let(:text_file) { File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'text-file.txt') }

    it 'has allowed attachment content type' do
      spree_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      expect(spree_image).to be_valid
    end

    it 'has no allowed attachment content type' do
      spree_image.attachment.attach(io: text_file, filename: 'text-file.txt', content_type: 'text/plain')
      expect(spree_image).not_to be_valid
    end
  end
end
