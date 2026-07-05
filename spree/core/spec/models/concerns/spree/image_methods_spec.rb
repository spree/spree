require 'spec_helper'


describe Spree::ImageMethods do
  describe '#generate_url' do
    let(:variant) { create(:variant) }
    let(:image) { create(:image, viewable: variant) }

    before (:each) do
      allow(image).to receive(:cdn_image_url)
    end

    context 'when gravity is not set to centre' do
      let(:gravity) { 'north' }

      it 'attachment.variant should receive the unchanged value of gravity' do
        expect(image.attachment).to receive(:variant).with(resize_and_pad: [48, 48, gravity: 'north'], saver: anything)
        image.generate_url(size: '48x48', gravity: gravity)
      end
    end

    context 'when gravity is set to centre' do
      let(:image) { create(:image, viewable: variant) }

      it 'attachment.variant should receive "gravity: center" when image processing variant is nil' do
        allow(Rails.application.config.active_storage).to receive(:variant_processor).and_return(nil)
        expect(image.attachment).to receive(:variant).with(resize_and_pad: [48, 48, gravity: 'center'], saver: anything)
        image.generate_url(size: '48x48')
      end

      it 'should return center when image processing variant is mini magick' do
        allow(Rails.application.config.active_storage).to receive(:variant_processor).and_return(:mini_magick)
        expect(image.attachment).to receive(:variant).with(resize_and_pad: [48, 48, gravity: 'center'], saver: anything)
        image.generate_url(size: '48x48')
      end

      it 'should return centre when image processing variant is VIPS' do
        allow(Rails.application.config.active_storage).to receive(:variant_processor).and_return(:vips)
        expect(image.attachment).to receive(:variant).with(resize_and_pad: [48, 48, gravity: 'centre'], saver: anything)
        image.generate_url(size: '48x48')
      end
    end
  end
end
