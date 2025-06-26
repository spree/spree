require 'spec_helper'

describe Spree::Admin::ImportsController, type: :controller, import: true do
  stub_authorization!

  render_views

  let(:store) { @default_store }
  let(:import) { create(:import, store: store, attachment: file_fixture('import/products_valid.csv') ) }

  describe '#index' do
    before { import }

    subject(:req) { get :index }

    it 'renders the index template' do
      req
      expect(response).to render_template(:index)
    end
  end

  describe '#new' do
    subject(:req) { get :new, params: { import: { type: 'Spree::Imports::Products' } } }

    it 'renders the new template' do
      expect(req).to render_template(:new)
    end

    it 'assigns permitted params' do
      req
      expect(assigns(:import).type).to eq('Spree::Imports::Products')
    end
  end

  describe '#errors' do
    subject(:req) { get :errors, params: { id: import.id } }

    it 'renders the new template' do
      expect(req).to render_template(:errors)
    end

    it 'assigns permitted params' do
      req
      expect(assigns(:import).type).to eq('Spree::Imports::Products')
    end
  end

  describe '#create' do
    subject(:req) { post :create, params: params, format: :turbo_stream }

    let(:params) do
      {
        import: {
          type: 'Spree::Imports::Products',
          attachment: fixture_file_upload('import/products_valid.csv')
        }
      }
    end

    it 'creates an import' do
      expect { req }.to change(Spree::Imports::Products, :count).by(1)

      expect(Spree::Imports::Products.last.user).to eq controller.try_spree_current_user
    end

    it 'sets a flash message' do
      req
      expect(flash[:success]).to eq('Import started.')
    end

    it 'calls the job', job: true do
      expect { req }.to have_enqueued_job(Spree::Imports::ExecuteJob)
    end
  end
end
