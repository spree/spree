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

  describe '#default_locale' do
    stub_authorization!

    let(:store) { Spree::Store.default }

    before do
      allow(controller).to receive(:current_store).and_return(store)
    end

    context 'when preferred_admin_locale is set' do
      before { allow(store).to receive(:preferred_admin_locale).and_return('de') }

      it 'uses the admin locale' do
        get :index
        expect(I18n.default_locale).to eq(:de)
      end
    end

    context 'when preferred_admin_locale is not set' do
      before { allow(store).to receive(:preferred_admin_locale).and_return(nil) }

      it 'falls back to store default_locale' do
        get :index
        expect(I18n.default_locale.to_s).to eq(store.default_locale)
      end
    end

    context 'when preferred_admin_locale is set and store has markets' do
      before do
        allow(store).to receive(:preferred_admin_locale).and_return('en')
        allow(store).to receive(:default_locale).and_return('fr')
      end

      it 'uses admin locale instead of market locale' do
        get :index
        expect(I18n.default_locale).to eq(:en)
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

      it 'redirects to admin login path' do
        get :index
        expect(response).to redirect_to('/admin/login')
      end
    end
  end
end
