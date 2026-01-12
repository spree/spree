require 'spec_helper'

RSpec.describe Spree::Admin::BulkOperationsController, type: :controller do
  stub_authorization!

  render_views

  describe '#new' do
    context 'with valid table_key and kind' do
      subject { get :new, params: { table_key: 'products', kind: 'set_active' } }

      it 'returns success' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'renders the bulk modal content partial' do
        expect(subject).to render_template(partial: 'spree/admin/shared/_bulk_modal_content')
      end

      it 'assigns bulk action attributes' do
        subject
        expect(assigns(:table_key)).to eq(:products)
        expect(assigns(:bulk_action)).to be_present
        expect(assigns(:bulk_action).key).to eq(:set_active)
      end

      it 'assigns title from bulk action' do
        subject
        expect(assigns(:title)).to be_present
      end

      it 'assigns body from bulk action' do
        subject
        expect(assigns(:body)).to be_present
      end

      it 'assigns default button_text' do
        subject
        expect(assigns(:button_text)).to eq(Spree.t(:confirm))
      end

      it 'assigns default button_class' do
        subject
        expect(assigns(:button_class)).to eq('btn-primary')
      end
    end

    context 'with bulk action that has form_partial' do
      subject { get :new, params: { table_key: 'products', kind: 'add_to_taxons' } }

      it 'assigns form_partial from bulk action' do
        subject
        expect(assigns(:form_partial)).to eq('spree/admin/bulk_operations/forms/taxon_picker')
      end
    end

    context 'with bulk action that has custom button options' do
      subject { get :new, params: { table_key: 'price_list_products', kind: 'remove_from_price_list' } }

      it 'assigns custom button_text' do
        subject
        expect(assigns(:button_text)).to eq(Spree.t(:remove))
      end

      it 'assigns custom button_class' do
        subject
        expect(assigns(:button_class)).to eq('btn-danger')
      end
    end

    context 'with invalid table_key' do
      subject { get :new, params: { table_key: 'nonexistent', kind: 'set_active' } }

      it 'returns not found' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid kind' do
      subject { get :new, params: { table_key: 'products', kind: 'nonexistent_action' } }

      it 'returns not found' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with missing table_key' do
      subject { get :new, params: { kind: 'set_active' } }

      it 'returns not found' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with missing kind' do
      subject { get :new, params: { table_key: 'products' } }

      it 'returns not found' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with blank parameters' do
      subject { get :new, params: { table_key: '', kind: '' } }

      it 'returns not found' do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'renders turbo frame' do
      subject { get :new, params: { table_key: 'products', kind: 'set_active' } }

      it 'includes turbo frame tag for bulk_dialog' do
        subject
        expect(response.body).to include('turbo-frame')
        expect(response.body).to include('bulk_dialog')
      end

      it 'includes dialog header' do
        subject
        expect(response.body).to include('dialog-header')
      end

      it 'includes dialog footer with buttons' do
        subject
        expect(response.body).to include('dialog-footer')
      end
    end
  end
end
