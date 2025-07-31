require 'spec_helper'

describe Spree::Admin::ReportsController, type: :controller do
  stub_authorization!

  let(:store) { @default_store }

  describe '#index' do
    subject { get :index }

    it 'renders the index template' do
      expect(subject).to render_template(:index)
    end
  end

  describe '#new' do
    subject { get :new, params: { type: 'sales_total' } }

    it 'builds a new report' do
      subject
      expect(assigns(:object)).to be_a_new(Spree::Reports::SalesTotal)
      expect(assigns(:object).store).to eq(store)
    end

    it 'sets the current user' do
      subject
      expect(assigns(:object).user).to eq(controller.try_spree_current_user)
    end

    it 'renders the new template' do
      expect(subject).to render_template(:new)
    end

    context 'with invalid report type' do
      subject { get :new, params: { type: 'invalid_type' } }

      it 'raises an error' do
        expect { subject }.to raise_error('Unknown report type')
      end
    end
  end

  describe '#create' do
    let(:report_params) do
      {
        type: 'sales_total',
        date_from: 1.month.ago,
        date_to: Time.current,
        currency: 'USD'
      }
    end

    subject { post :create, params: { report: report_params } }

    it 'creates a new report' do
      expect { subject }.to change(Spree::Report, :count).by(1)
    end

    it 'sets the store' do
      subject
      expect(assigns(:object).store).to eq(store)
    end

    it 'sets the current user' do
      subject
      expect(assigns(:object).user).to eq(controller.try_spree_current_user)
    end

    it 'sets success flash message' do
      subject
      expect(flash[:success]).to eq Spree.t('admin.report_created')
    end
  end

  describe '#show' do
    let(:report) { create(:report, store: store) }

    before do
      allow_any_instance_of(Spree::Reports::SalesTotal).to receive_message_chain(:attachment, :url).and_return('http://example.com/test.csv')
    end

    subject { get :show, params: { id: report.id } }

    it 'downloads the export' do
      subject
      expect(response).to have_http_status(:see_other)
      expect(response.headers['Location']).to eq(report.attachment.url)
    end
  end
end
