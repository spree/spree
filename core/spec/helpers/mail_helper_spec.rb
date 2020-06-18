require 'spec_helper'

module Spree
  describe MailHelper, type: :helper do
    describe '#variant_image_url' do
      subject { helper.variant_image_url(variant) }

      let(:variant) { create(:variant, images: images) }

      context 'with no images' do
        let(:images) { [] }

        specify 'returns placeholder path' do
          expect(subject).to eq 'noimage/small.png'
        end
      end

      context 'with images' do
        let(:images) { [image] }
        let(:image) { create(:image) }

        specify 'returns proper image path' do
          expect(subject).to eq main_app.url_for(image.url(:small))
        end
      end
    end
  end
end
