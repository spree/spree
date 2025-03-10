require 'spec_helper'

describe Spree::Admin::DashboardController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }

  describe '#show' do
    it 'renders welcome page' do
      get :show
      expect(response).to render_template(:show)
    end
  end

  describe '#analytics' do
    context 'view' do
      it 'renders analytics' do
        get :analytics
        expect(response).to render_template(:analytics)
      end

      context 'with data' do
        before do
          create_list(:completed_order_with_totals, 3, store: store)
        end

        it 'renders analytics' do
          get :analytics
          expect(response).to render_template(:analytics)
        end

        it 'renders top products' do
          get :analytics
          expect(assigns(:top_products)).to be_present
          expect(response.body).to include('Top products')
          expect(response.body).to include('View report')
        end
      end
    end
  end

  describe '#getting_started' do
    it 'renders getting started' do
      get :getting_started
      expect(response).to render_template(:getting_started)
    end
  end
end
