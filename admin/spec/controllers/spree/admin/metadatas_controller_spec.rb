require 'spec_helper'

describe Spree::Admin::MetadatasController, type: :controller do
  stub_authorization!

  let(:product) { create(:product) }

  describe 'GET #edit' do
    subject { get :edit, params: { id: product.id, resource_type: 'Spree::Product' } }

    it 'assigns the resource' do
      subject
      expect(assigns(:resource)).to eq(product)
    end

    it 'assigns resource_name' do
      subject
      expect(assigns(:resource_name)).to eq(product.name)
    end

    context 'with invalid resource_type' do
      it 'raises RecordNotFound' do
        expect do
          get :edit, params: { id: product.id, resource_type: 'Invalid' }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: metadata_params }

    let(:metadata_params) do
      {
        id: product.id,
        resource_type: 'Spree::Product',
        private_metadata: {
          '0' => { key: 'test_key', value: 'test_value' }
        },
        public_metadata: {
          '0' => { key: 'public_key', value: 'public_value' }
        }
      }
    end

    it 'updates private metadata' do
      subject
      expect(product.reload.private_metadata).to eq({ 'test_key' => 'test_value' })
    end

    it 'updates public metadata' do
      subject
      expect(product.reload.public_metadata).to eq({ 'public_key' => 'public_value' })
    end

    it 'sets success flash message' do
      subject
      expect(flash[:success]).to be_present
    end

    it 'redirects to edit page' do
      expect(subject).to redirect_to(spree.edit_admin_metadata_path(product, resource_type: 'Spree::Product'))
    end

    context 'with invalid params' do
      before do
        allow_any_instance_of(Spree::Product).to receive(:update).and_return(false)
        allow_any_instance_of(Spree::Product).to receive(:errors).and_return(ActiveModel::Errors.new(product).tap { |e| e.add(:base, 'Error') })
      end

      it 'renders edit template' do
        expect(subject).to render_template(:edit)
      end

      it 'sets error flash message' do
        subject
        expect(flash.now[:error]).to be_present
      end
    end
  end
end
