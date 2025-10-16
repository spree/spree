require 'spec_helper'

RSpec.describe Spree::Admin::ImportsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:attachment) { Rack::Test::UploadedFile.new(File.join(Spree::Core::Engine.root, 'spec/fixtures/files', 'products_import.csv'), 'text/csv') }
  let(:csv_content) { File.read(File.join(Spree::Core::Engine.root, 'spec/fixtures/files', 'products_import.csv')) }

  before do
    # Stub the file content reading since ActiveStorage doesn't persist files properly in transactional tests
    allow_any_instance_of(Spree::Import).to receive(:attachment_file_content).and_return(csv_content)
  end

  describe 'GET #new' do
    it 'assigns a new import and renders the new template' do
      get :new
      expect(response).to render_template(:new)
      expect(assigns(:import)).to be_a(Spree::Import)
      expect(assigns(:import)).to be_new_record
      expect(assigns(:import).type).to eq(Spree::Import.available_types.first.to_s)
    end

    context 'when type parameter is present' do
      it 'assigns the type' do
        get :new, params: { import: { type: 'Spree::Imports::Products' } }
        expect(assigns(:import).type).to eq('Spree::Imports::Products')
      end
    end
  end

  describe 'POST #create' do
    let(:import_params) { { type: Spree::Import.available_types.first.to_s, attachment: attachment } }

    it 'creates a new import and redirects to show' do
      expect {
        post :create, params: { import: import_params }
      }.to change(Spree::Import, :count).by(1)

      import = Spree::Import.last
      expect(response).to redirect_to(spree.admin_import_path(import))
      expect(import.user).to eq(admin_user)
      expect(import.owner).to eq(store)
      expect(import.type).to eq(Spree::Import.available_types.first.to_s)
      expect(import.attachment).to be_attached
      expect(import.attachment.filename.to_s).to eq('products_import.csv')
    end

    context 'when type parameter is present' do
      it 'assigns the type' do
        post :create, params: { import: import_params }
        expect(assigns(:import).type).to eq('Spree::Imports::Products')
      end
    end
  end

  describe 'GET #show' do
    let(:import) do
      # Stub the file content reading since ActiveStorage doesn't persist files properly in transactional tests
      allow_any_instance_of(Spree::Import).to receive(:attachment_file_content).and_return(csv_content)
      create(:product_import)
    end

    it 'renders the show template' do
      get :show, params: { id: import.id }
      expect(response).to render_template(:show)
      expect(assigns(:import)).to eq(import)
    end
  end

  describe 'PUT #complete_mapping' do
    let(:import) { create(:product_import) }

    context 'when mapping is done' do
      before do
        allow_any_instance_of(Spree::Import).to receive(:mapping_done?).and_return(true)
        allow_any_instance_of(Spree::Import).to receive(:completed_mapping!).and_call_original
      end

      it 'marks import as completed and redirects to show' do
        expect_any_instance_of(Spree::Import).to receive(:completed_mapping!)
        put :complete_mapping, params: { id: import.id }
        expect(response).to redirect_to(spree.admin_import_path(import))
      end
    end

    context 'when mapping is not done' do
      before do
        allow_any_instance_of(Spree::Import).to receive(:mapping_done?).and_return(false)
      end

      it 'does not mark import as completed but still redirects to show' do
        expect_any_instance_of(Spree::Import).not_to receive(:completed_mapping!)
        put :complete_mapping, params: { id: import.id }
        expect(response).to redirect_to(spree.admin_import_path(import))
      end
    end
  end
end
