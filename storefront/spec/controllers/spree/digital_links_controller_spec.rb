require 'spec_helper'

RSpec.describe Spree::DigitalLinksController, type: :controller do
  let(:digital_shipping_method) { create(:digital_shipping_method) }
  let(:order) { create(:order) }
  let(:product) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
  let(:digital) { create(:digital) }
  let(:variant) { create(:variant, digitals: [digital], product: product) }
  let!(:line_item) { create(:line_item, order: order, variant: variant) }
  let(:digital_link) { create(:digital_link, line_item: line_item, digital: digital) }
  let!(:shipment) do
    create(:shipment, state: 'ready', order: order).tap do |shipment|
      shipment.shipping_methods.delete_all
      shipment.add_shipping_method(digital_shipping_method, true)
    end
  end

  describe '#show' do
    context 'with valid digital link' do
      context 'when first access' do
        it 'marks shipment as fulfilled' do
          allow(controller).to receive(:send_file)
          get :show, params: { id: digital_link.token }
          expect(shipment.reload.state).to eq('shipped')
        end
      end

      context 'when using DiskService' do
        it 'sends the file directly' do
          expect(controller).to receive(:send_file).with(
            anything,
            filename: digital.filename,
            type: digital.content_type,
            status: :ok
          )
          get :show, params: { id: digital_link.token }
        end
      end

      context 'when using cloud storage' do
        before do
          stub_const('ActiveStorage::Service::S3Service', Class.new)
          allow(ActiveStorage::Blob).to receive(:service).and_return(
            instance_double('ActiveStorage::Service::S3Service', instance_of?: false)
          )
          allow_any_instance_of(ActiveStorage::Attachment).to receive(:url).with(
            expires_in: @default_store.preferred_digital_asset_link_expire_time.seconds,
            disposition: 'attachment'
          ).and_return('https://example.com/file.pdf')
        end

        it 'redirects to the cloud storage URL' do
          get :show, params: { id: digital_link.token }
          expect(response).to redirect_to('https://example.com/file.pdf')
        end
      end
    end

    context 'with unauthorized digital link' do
      before do
        digital_link.update(access_counter: @default_store.preferred_digital_asset_authorized_clicks + 1)
      end

      it 'redirects to order path with error' do
        get :show, params: { id: digital_link.token }
        expect(flash[:error]).to eq Spree.t(:digital_link_unauthorized)
        expect(response).to redirect_to(spree.order_path(order))
      end
    end

    context 'with invalid digital link token' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect do
          get :show, params: { id: 'invalid_token' }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
