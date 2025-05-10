require 'spec_helper'

describe Spree::Admin::CustomDomainsController, type: :controller do
  stub_authorization!

  render_views

  let(:store) { Spree::Store.default }

  describe '#new' do
    subject { get :new, format: :html }

    it 'renders new template' do
      subject
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe '#create' do
    subject { post :create, params: params, format: :html }

    let(:params) do
      {
        custom_domain: {
          url: 'test-domain.com',
        }
      }
    end

    context 'with valid params' do
      it 'creates a new custom domain' do
        expect { subject }.to change(Spree::CustomDomain, :count).by(1)

        expect(response).to redirect_to(spree.admin_custom_domains_path)

        custom_domain = Spree::CustomDomain.last
        expect(custom_domain.url).to eq('test-domain.com')
        expect(custom_domain.store).to eq(store)
        expect(custom_domain.default).to be_truthy
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          custom_domain: {
            url: ''
          }
        }
      end

      it 'does not create a custom domain' do
        expect { subject }.not_to change(Spree::CustomDomain, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe '#edit' do
    subject { get :edit, params: { id: custom_domain.id } }

    let!(:custom_domain) { create(:custom_domain, store: store) }

    it 'renders edit template' do
      subject
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end
  end

  describe '#update' do
    subject { put :update, params: params }

    let!(:custom_domain) { create(:custom_domain, store: store) }

    let(:params) do
      {
        id: custom_domain.id,
        custom_domain: {
          url: 'updated-domain.com'
        }
      }
    end

    context 'with valid params' do
      it 'updates the custom domain' do
        expect { subject }.to change { custom_domain.reload.url }.to('updated-domain.com')

        expect(response).to redirect_to(spree.admin_custom_domains_path)
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          id: custom_domain.id,
          custom_domain: {
            url: ''
          }
        }
      end

      it 'does not update the custom domain' do
        expect { subject }.not_to change { custom_domain.reload.url }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end
end
