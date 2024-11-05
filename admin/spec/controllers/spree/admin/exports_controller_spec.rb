require 'spec_helper'

describe Spree::Admin::ExportsController, type: :controller do
  stub_authorization!

  let(:store) { Spree::Store.default }

  describe '#new' do
    subject { get :new, params: { export: { type: 'Spree::Exports::Products', search_params: { name_cont: 'Product' }.as_json } } }

    it 'renders the new template' do
      expect(subject).to render_template(:new)
    end

    it 'assigns permitted params' do
      subject
      expect(assigns(:export).type).to eq('Spree::Exports::Products')
      expect(assigns(:export).search_params).to eq({ 'name_cont' => 'Product' })
    end
  end

  describe '#create' do
    subject { post :create, params: params, format: :turbo_stream }

    let(:params) do
      {
        export: {
          type: 'Spree::Exports::Products',
          format: 'csv',
          search_params: {
            name_cont: 'Product'
          }.as_json,
          record_selection: 'filtered'
        }
      }
    end

    it 'creates the export' do
      expect { subject }.to change(Spree::Exports::Products, :count).by(1)

      export = Spree::Exports::Products.last
      expect(export.user).to eq(controller.try_spree_current_user)
      expect(export.format).to eq('csv')
      expect(export.search_params).to eq({ 'name_cont' => 'Product' })
    end

    it 'sets a flash message' do
      subject
      expect(flash[:success]).to eq('Your export was started. You will receive an email with a download link when it is ready!')
    end

    context 'when filtered is set to all' do
      subject { post :create, params: params.merge(export: { record_selection: 'all' }), format: :turbo_stream }

      it 'does not assign search_params' do
        subject
        expect(assigns(:export).search_params).to be_nil
      end
    end
  end
end
