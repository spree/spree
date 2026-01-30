require 'spec_helper'

describe Spree::Admin::AssetsController, type: :controller do
  stub_authorization!

  render_views

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

        expect(response).to have_http_status(:ok)

        expect(asset.alt).to eq("some text")
        expect(asset.attached?).to be true
        expect(asset.viewable).to be_nil
        expect(asset.session_id).to eq(request.session['spree.admin.uploaded_assets.uuid'])
      end
    end

    context 'with viewable' do
      subject { post :create, params: params, format: :turbo_stream }

      let(:params) do
        { asset: { alt: "some text", attachment: attachment, viewable_id: product.master.id, viewable_type: "Spree::Variant" } }
      end

      it 'creates a new image' do
        expect { subject }.to change(Spree::Asset, :count).by(1)

        expect(response).to have_http_status(:ok)

        expect(asset.viewable).to eq(product.master)
        expect(asset.session_id).to be_nil
      end
    end

    context 'with viewable and type Spree::Image' do
      subject { post :create, params: params, format: :turbo_stream }

      let(:params) do
        { asset: { type: 'Spree::Image', alt: "some text", attachment: attachment, viewable_id: product.master.id, viewable_type: "Spree::Variant" } }
      end

      it 'creates a new Spree::Image' do
        expect { subject }.to change(Spree::Image, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(Spree::Image.last.viewable).to eq(product.master)
      end

      it 'increments variant image_count counter cache' do
        expect { subject }.to change { product.master.reload.image_count }.by(1)
      end

      it 'increments product total_image_count counter cache' do
        expect { subject }.to change { product.reload.total_image_count }.by(1)
      end
    end
  end

  describe '#update' do
    subject { put :update, params: { id: image.to_param, asset: { alt: 'Alt text' } }, as: :turbo_stream }

    let!(:image) { create(:image, viewable: product.master) }

    it 'updates the image' do
      subject

      expect(response).to have_http_status(:ok)
      expect(image.reload.alt).to eq('Alt text')
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: image.to_param }, format: :turbo_stream }

    let!(:image) { create(:image, viewable: product.master) }

    it 'deletes the image' do
      expect { subject }.to change(Spree::Asset, :count).by(-1)
      expect(response).to have_http_status(:ok)
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
      expect(response).to have_http_status(:ok)
    end
  end
end
