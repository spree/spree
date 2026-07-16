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

    around do |example|
      original_default_locale = I18n.default_locale
      original_locale = I18n.locale
      example.run
    ensure
      I18n.default_locale = original_default_locale
      I18n.locale = original_locale
    end

    before do
      allow(controller).to receive(:current_store).and_return(store)
    end

    context 'when preferred_admin_locale is set' do
      before { allow(store).to receive(:preferred_admin_locale).and_return('de') }

      it 'uses the admin locale for the UI chrome' do
        get :index
        expect(I18n.locale).to eq(:de)
      end

      it 'keeps the content locale on the store locale, not the admin UI locale' do
        # `Spree::Current.content_locale` must track the store content locale so
        # it matches `Mobility.locale`; binding it to the admin UI language
        # desyncs Mobility and breaks ordered + DISTINCT listings.
        # (Direct call: the test-request executor resets Spree::Current before
        # a post-`get` assertion could see it.)
        controller.send(:set_locale)
        expect(Spree::Current.content_locale).to eq(store.default_locale)
      end
    end

    context 'when preferred_admin_locale is set and store has markets' do
      before do
        allow(store).to receive(:preferred_admin_locale).and_return('en')
        allow(store).to receive(:default_locale).and_return('fr')
      end

      it 'uses the admin locale for the UI chrome' do
        get :index
        expect(I18n.locale).to eq(:en)
      end

      it 'keeps the content locale on the store locale' do
        controller.send(:set_locale)
        expect(Spree::Current.content_locale).to eq('fr')
      end
    end
  end

  describe '#current_locale' do
    stub_authorization!

    let(:store) { Spree::Store.default }

    around do |example|
      original_locale = I18n.locale
      example.run
    ensure
      I18n.locale = original_locale
    end

    before do
      allow(controller).to receive(:current_store).and_return(store)
      allow(store).to receive(:preferred_admin_locale).and_return('en')
      allow(Spree).to receive(:available_locales).and_return(%i[en de fr])
    end

    context "when the current user has a selected_locale" do
      before { allow(controller).to receive(:admin_user_selected_locale).and_return('de') }

      it "uses the user's locale over the store admin locale" do
        get :index
        expect(I18n.locale).to eq(:de)
      end
    end

    context "when the user's selected_locale is not an available admin locale" do
      before { allow(controller).to receive(:admin_user_selected_locale).and_return('pl') }

      it 'ignores it and falls back to the store admin locale' do
        get :index
        expect(I18n.locale).to eq(:en)
      end
    end

    context 'when the user has no selected_locale' do
      before { allow(controller).to receive(:admin_user_selected_locale).and_return(nil) }

      it 'honors the admin locale cookie (set on the login screen)' do
        request.cookies[Spree::Admin::LocaleConcern::ADMIN_LOCALE_COOKIE.to_s] = 'fr'
        get :index
        expect(I18n.locale).to eq(:fr)
      end

      it 'ignores an unsupported cookie value' do
        request.cookies[Spree::Admin::LocaleConcern::ADMIN_LOCALE_COOKIE.to_s] = 'pl'
        get :index
        expect(I18n.locale).to eq(:en)
      end

      it 'falls back to the store admin locale when no cookie is set' do
        get :index
        expect(I18n.locale).to eq(:en)
      end
    end
  end

  describe '#set_locale (UI vs content locale decoupling)' do
    stub_authorization!

    let(:store) { Spree::Store.default }

    around do |example|
      original_i18n = I18n.locale
      original_default = I18n.default_locale
      original_mobility = Mobility.locale
      example.run
    ensure
      I18n.locale = original_i18n
      I18n.default_locale = original_default
      Mobility.locale = original_mobility
    end

    before do
      allow(controller).to receive(:current_store).and_return(store)
      # Store content locale (fr) is deliberately distinct from both the chosen
      # UI locale (de) and the app default (en), so each assertion pins down a
      # specific locale rather than passing by coincidence.
      allow(store).to receive_messages(preferred_admin_locale: 'en', default_locale: 'fr')
      allow(Spree).to receive(:available_locales).and_return(%i[en de fr])
      allow(controller).to receive(:admin_user_selected_locale).and_return('de')
    end

    it 'sets the UI locale (I18n) to the selected admin language' do
      get :index
      expect(I18n.locale).to eq(:de)
    end

    it "pins the content locale (Mobility) to the store's content locale, not the UI locale" do
      get :index
      expect(Mobility.locale).to eq(:fr)
    end

    it 'keeps the request content locale aligned with Mobility' do
      # Mobility's column_fallback reads the base column only when the locale
      # equals the request's content locale; if they diverge, translated
      # listings JOIN the translations table and ordered + DISTINCT queries raise.
      controller.send(:set_locale)
      expect(Spree::Current.content_locale).to eq('fr')
      expect(Mobility.locale).to eq(:fr)
    end

    it 'leaves the process-global I18n.default_locale untouched' do
      expect { get :index }.not_to change(I18n, :default_locale)
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
