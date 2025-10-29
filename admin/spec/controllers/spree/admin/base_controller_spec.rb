require 'spec_helper'

class AdminFakesController < Spree::Admin::BaseController
  def index
    render plain: 'index'
  end
end

describe Spree::Admin::BaseController, type: :controller do
  controller(Spree::Admin::BaseController) do
    def index
      authorize! :update, Spree::Order
      render plain: 'test'
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
