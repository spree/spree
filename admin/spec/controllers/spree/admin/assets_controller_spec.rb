require 'spec_helper'

describe Spree::Admin::AssetsController, type: :controller do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:product) { create(:product, stores: [store]) }

  describe '#create' do
    subject { post :create, params: params, format: :turbo_stream }

    let(:attachment) { Rack::Test::UploadedFile.new(File.join(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'), 'image/jpeg') }
    let(:asset) { Spree::Asset.last }

    context 'without viewable' do
      let(:params) { { asset: { alt: "some text", attachment: attachment } } }

      it 'creates a new image' do
        expect { subject }.to change(Spree::Asset, :count).by(1)

        expect(asset.alt).to eq("some text")
        expect(asset.attached?).to be true
        expect(asset.viewable).to be_nil
        expect(asset.session_uploaded_assets_uuid).to eq(request.session['spree.admin.uploaded_assets.uuid'])
      end
    end

    context 'with viewable' do
      subject { post :create, params: params, format: :turbo_stream }

      let(:params) do
        { asset: { alt: "some text", attachment: attachment, viewable_id: product.master.id, viewable_type: "Spree::Variant" } }
      end

      it 'creates a new image' do
        expect { subject }.to change(Spree::Asset, :count).by(1)

        expect(asset.viewable).to eq(product.master)
        expect(asset.session_uploaded_assets_uuid).to be_nil
      end
    end
  end

  describe '#update' do
    subject { put :update, params: { id: image.id, asset: { alt: 'Alt text' } }, as: :turbo_stream }

    let!(:image) { create(:image, viewable: product.master) }

    it 'updates the image' do
      subject
      expect(image.reload.alt).to eq('Alt text')
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: image.id } }

    let!(:image) { create(:image, viewable: product.master) }

    it 'deletes the image' do
      expect { subject }.to change(Spree::Asset, :count).by(-1)
    end
  end

  describe '#bulk_destroy' do
    subject { delete :bulk_destroy, params: params, as: :turbo_stream }

    let!(:images) { create_list(:image, 2, viewable: product.master) }
    let(:params) do
      {
        ids: images.map(&:id)
      }
    end

    it 'deletes images' do
      expect { subject }.to change(Spree::Asset, :count).by(-2)
    end
  end
end
