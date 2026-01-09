require 'spec_helper'

class AdminFakesController < Spree::Admin::BaseController
  def index
    render plain: 'index'
  end
end

describe Spree::Admin::BaseController, type: :controller do
  controller(Spree::Admin::BaseController) do
    def index
      @timezone_used = Time.zone.name
      render plain: 'test'
    end
  end

  describe '#current_timezone' do
    stub_authorization!

    before do
      allow(Spree::Config).to receive(:timezones).and_return([:local, :store])
      allow(controller).to receive(:current_store).and_return(store)
    end

    let(:store) { create(:store, preferred_timezone: store_timezone) }
    let(:store_timezone) { 'America/New_York' }

    context 'with valid cookie timezone' do
      before do
        cookies[:tz] = 'Europe/Warsaw'
      end

      it 'returns the correct timezone' do
        get :index
        expect(assigns(:timezone_used)).to eq('Europe/Warsaw')
      end
    end

    context 'with invalid or none cookie timezone' do
      before do
        cookies[:tz] = 'Invalid/Timezone'
      end

      context 'when fallback is :store' do
        before do
          allow(Spree::Config).to receive(:timezones).and_return([:local, :store])
        end

        it 'returns store\'s timezone' do
          get :index
          expect(assigns(:timezone_used)).to eq('America/New_York')
        end
      end

      context 'when fallback is :application' do
        before do
          allow(Spree::Config).to receive(:timezones).and_return([:local, :application])
        end

        it 'returns application\'s timezone' do
          get :index
          expect(assigns(:timezone_used)).to eq(Time.zone_default.name)
        end
      end
    end
  end

  describe '#redirect_unauthorized_access' do
    controller(AdminFakesController) do
      def index
        redirect_unauthorized_access
      end
    end
    context 'when logged in' do
      before do
        allow(controller).to receive_messages(try_spree_current_user: double('User', id: 1, last_incomplete_spree_order: nil,
                                                                             persisted?: true, selected_locale: nil))
      end

      it 'redirects back to referer when present and shows a flash error' do
        request.env['HTTP_REFERER'] = '/admin/products'
        get :index
        expect(response).to redirect_to('/admin/products')
        expect(flash[:error]).to eq(Spree.t(:authorization_failure))
      end

      it 'redirects to forbidden path as fallback when no referer and shows a flash error' do
        get :index
        expect(response).to redirect_to('/admin/forbidden')
        expect(flash[:error]).to eq(Spree.t(:authorization_failure))
      end
    end

    context 'when guest user' do
      before do
        allow(controller).to receive_messages(try_spree_current_user: nil)
      end

      it 'redirects admin login path' do
        allow(controller).to receive_messages(spree_admin_login_path: '/admin/login')
        get :index
        expect(response).to redirect_to('/admin/login')
      end

      it 'redirects login path' do
        allow(controller).to receive_messages(spree_login_path: '/login')
        get :index
        expect(response).to redirect_to('/login')
      end

      context 'redirects to root' do
        it 'of spree' do
          allow(controller).to receive_message_chain(:spree, :root_path).and_return('/root')
          get :index
          expect(response).to redirect_to '/root'
        end

        it 'of main app' do
          get :index
          expect(response).to redirect_to '/'
        end
      end
    end
  end
end
