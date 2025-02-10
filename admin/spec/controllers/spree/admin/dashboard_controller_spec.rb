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
    end
  end

  describe '#getting_started' do
    it 'renders getting started' do
      get :getting_started
      expect(response).to render_template(:getting_started)
    end
  end
end
