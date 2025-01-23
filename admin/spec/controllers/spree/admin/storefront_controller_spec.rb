require 'spec_helper'

describe Spree::Admin::StorefrontController do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }
  let!(:uk_country) { create(:country, iso: 'GB', iso3: 'GBR', name: 'United Kingdom') }

  describe 'GET #edit' do
    subject { get :edit, params: { id: store.id } }

    it 'renders the edit template' do
      subject
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    subject { patch :update, params: { id: store.id, store: store_params, **other_params } }

    let(:store_params) do
      {
        name: 'New Store Name',
        meta_description: 'This is a cool store',
      }
    end

    let(:other_params) { {} }

    it 'updates the store data' do
      subject

      expect(store.reload.name).to eq('New Store Name')
      expect(store.meta_description).to eq('This is a cool store')
    end

    context 'when removing assets' do
      let(:image_path) { Spree::Core::Engine.root.join('spec/fixtures/files/icon_256x256.png') }
      let(:image_file) { Rack::Test::UploadedFile.new(image_path, 'image/png') }

      context 'when removing the favicon' do
        let(:other_params) { { remove_favicon_image: '1' } }

        before { store.favicon_image.attach(image_file) }

        it 'removes the favicon' do
          expect { subject }.to change { store.reload.favicon_image.attached? }.from(true).to(false)
        end
      end

      context 'when removing the social image' do
        let(:other_params) { { remove_social_image: '1' } }

        before { store.social_image.attach(image_file) }

        it 'removes the social image' do
          expect { subject }.to change { store.reload.social_image.attached? }.from(true).to(false)
        end
      end
    end
  end
end
