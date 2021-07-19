# Spree's rpsec controller tests get the Spree::ControllerHacks
# we don't need those for the anonymous controller here, so
# we call process directly instead of get
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

  context '#generate_api_key' do
    let(:user) { mock_model(Spree.user_class, has_spree_role?: true) }

    before do
      allow(controller).to receive(:authorize_admin).and_return(true)
      allow(controller).to receive(:try_spree_current_user) { user }
    end

    it 'generates the API key for a user when they visit' do
      expect(user).to receive(:spree_api_key).and_return(nil)
      expect(user).to receive(:generate_spree_api_key!)
      get :index
    end

    it 'does not attempt to regenerate the API key if the key is already set' do
      expect(user).to receive(:spree_api_key).and_return('fake')
      expect(user).not_to receive(:generate_spree_api_key!)
      get :index
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
        allow(controller).to receive_messages(try_spree_current_user: double('User', id: 1, last_incomplete_spree_order: nil))
      end

      it 'redirects forbidden path' do
        get :index
        expect(response).to redirect_to('/admin/forbidden')
      end
    end

    context 'when guest user' do
      before do
        allow(controller).to receive_messages(try_spree_current_user: nil)
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
