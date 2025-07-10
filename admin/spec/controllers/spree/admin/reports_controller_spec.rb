require 'spec_helper'

describe Spree::Admin::ReportsController, type: :controller do
  stub_authorization!

  render_views

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

    context 'when dates are provided' do
      subject { get :new, params: { type: 'sales_total', date_from: date_from, date_to: date_to } }

      let(:date_from) { 'Tue Jul 08 2025 00:00:00 GMT+0200 (czas środkowoeuropejski letni)' }
      let(:date_to) { 'Tue Jul 09 2025 00:00:00 GMT+0200 (czas środkowoeuropejski letni)' }

      it 'sets the dates in the store timezone' do
        subject
        expect(assigns(:object).date_from).to eq(date_from.to_date.in_time_zone(store.preferred_timezone))
        expect(assigns(:object).date_to.change(usec: 0)).to eq(date_to.to_date.in_time_zone(store.preferred_timezone).end_of_day.change(usec: 0))
      end
    end

    context 'when no dates are provided' do
      subject { get :new, params: { type: 'sales_total' } }

      before { Timecop.freeze(Time.current) }

      after { Timecop.return }

      it 'sets default values' do
        subject
        expect(assigns(:object).date_from).to eq(1.month.ago.in_time_zone(store.preferred_timezone).beginning_of_day)
        expect(assigns(:object).date_to.change(usec: 0)).to eq(Time.current.in_time_zone(store.preferred_timezone).end_of_day.change(usec: 0))
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

    subject { post :create, params: { report: report_params }, format: :turbo_stream }

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

    context 'when dates with different timezones are provided' do
      let(:date_from) { 'Tue Jul 08 2025 00:00:00 GMT+0200 (czas środkowoeuropejski letni)' }
      let(:date_to) { 'Tue Jul 09 2025 00:00:00 GMT+0200 (czas środkowoeuropejski letni)' }

      let(:report_params) do
        {
          type: 'sales_total',
          date_from: date_from,
          date_to: date_to,
          currency: 'USD'
        }
      end

      it 'sets the dates in the store timezone' do
        subject
        expect(assigns(:object).date_from).to eq(date_from.to_date.in_time_zone(store.preferred_timezone))
        expect(assigns(:object).date_to.change(usec: 0)).to eq(date_to.to_date.in_time_zone(store.preferred_timezone).end_of_day.change(usec: 0))
      end
    end

    context 'when no dates are provided' do
      let(:report_params) { { type: 'sales_total', currency: 'USD' } }

      before { Timecop.freeze(Time.current) }

      after { Timecop.return }

      it 'sets default values' do
        subject
        expect(assigns(:object).date_from).to eq(1.month.ago.in_time_zone(store.preferred_timezone).beginning_of_day)
        expect(assigns(:object).date_to.change(usec: 0)).to eq(Time.current.in_time_zone(store.preferred_timezone).end_of_day.change(usec: 0))
      end
    end
  end
end
