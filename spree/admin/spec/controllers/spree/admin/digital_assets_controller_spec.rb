require 'spec_helper'

describe Spree::Admin::DigitalAssetsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { product.master }
  let(:attachment) { Rack::Test::UploadedFile.new(File.join(Spree::Core::Engine.root, 'spec/fixtures', 'thinking-cat.jpg'), 'image/jpeg') }

  describe '#create' do
    subject { post :create, params: params }

    let(:params) do
      {
        product_id: product.slug,
        digital_asset: {
          variant_id: variant.id,
          attachment: attachment
        }
      }
    end

    it 'creates a new digital with attachment' do
      expect { subject }.to change(Spree::Digital, :count).by(1)

      digital = Spree::Digital.last
      expect(digital.variant).to eq(variant)
      expect(digital.attachment).to be_attached
      expect(digital.attachment.filename.to_s).to eq('thinking-cat.jpg')
    end

    context 'with invalid params' do
      let(:params) do
        {
          product_id: product.slug,
          digital_asset: {
            variant_id: variant.id
          }
        }
      end

      it 'does not create a digital' do
        expect { subject }.not_to change(Spree::Digital, :count)
      end
    end
  end

  describe '#update' do
    subject { put :update, params: params }

    let!(:digital) { create(:digital, variant: variant) }
    let(:new_attachment) { Rack::Test::UploadedFile.new(File.join(Spree::Core::Engine.root, 'spec/fixtures', 'thinking-cat.jpg'), 'image/jpeg') }

    let(:params) do
      {
        product_id: product.slug,
        id: digital.id,
        digital_asset: {
          attachment: new_attachment
        }
      }
    end

    it 'updates the digital with new attachment' do
      subject

      digital.reload
      expect(digital.attachment).to be_attached
      expect(digital.attachment.filename.to_s).to eq('thinking-cat.jpg')
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: params }

    let!(:digital) { create(:digital, variant: variant) }

    let(:params) do
      {
        product_id: product.slug,
        id: digital.to_param
      }
    end

    it 'deletes the digital' do
      expect { subject }.to change(Spree::Digital, :count).by(-1)
    end
  end
end
