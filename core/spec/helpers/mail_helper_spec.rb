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

    describe '#name_for' do
      subject { helper.name_for(order) }

      let(:order) { create(:order, ship_address_id: nil, bill_address_id: nil) }
      let(:address) { create(:address) }

      context 'without address' do
        it 'shows default name' do
          expect(subject).to eq Spree.t('customer')
        end
      end

      context 'with address' do
        before do
          order.update(ship_address: address)
        end

        it 'shows customer full name' do
          expect(subject).to eq address.full_name
        end
      end
    end

    describe '#logo_path' do
      subject { helper.logo_path }

      let(:store) { create(:store) }

      before do
        allow(helper).to receive(:current_store) { store }
      end

      context 'when no custom logo attached' do
        it 'shows default mailer logo' do
          expect(subject).to eq Spree::Config.mailer_logo
        end
      end

      context 'when @order exists' do
        let(:logo_image) { File.open(File.expand_path('../../app/assets/images/logo/spree_50.png', __dir__)) }

        before do
          store.mailer_logo.attach(io: logo_image, filename: 'spree_50.png', content_type: 'image/png')
          @order = create(:order, store: store)
        end

        it 'shows logo attached to orders store' do
          expect(subject).to include(store.mailer_logo.attachment.filename.to_s)
        end
      end

      context 'when @order does not exist' do
        let(:logo_image) { File.open(File.expand_path('../../app/assets/images/noimage/mini.png', __dir__)) }

        before do
          store.mailer_logo.attach(io: logo_image, filename: 'mini.png', content_type: 'image/png')
        end

        it 'shows logo attached to current store' do
          expect(subject).to include(store.mailer_logo.attachment.filename.to_s)
        end
      end
    end
  end
end
