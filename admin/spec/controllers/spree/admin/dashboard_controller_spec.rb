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

  describe '#dismiss_enterprise_edition_notice' do
    it 'dismisses the enterprise edition notice' do
      patch :dismiss_enterprise_edition_notice
      expect(response).to redirect_to(spree.admin_dashboard_path)
      expect(session[:spree_enterprise_edition_notice_dismissed]).to be_truthy
    end
  end

  describe '#dismiss_updater_notice' do
    it 'dismisses the updater notice' do
      patch :dismiss_updater_notice
      expect(response).to redirect_to(spree.admin_dashboard_path)
      expect(session[:spree_updater_notice_dismissed]).to include(
        value: true,
        expires_at: be_within(1.second).of(7.days.from_now)
      )
    end
  end
end
