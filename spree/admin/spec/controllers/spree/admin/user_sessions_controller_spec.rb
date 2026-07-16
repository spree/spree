require 'spec_helper'

describe Spree::Admin::UserSessionsController, type: :controller do
  # The real Devise sign-in routes are mounted by the host-app auth installer,
  # not the admin engine's dummy app. Expose a routable action here so we can
  # drive the `set_login_locale` before_action through a real request and
  # assert on the response cookie + I18n.locale.
  stub_authorization!

  controller(described_class) do
    # In the engine's dummy app Devise isn't loaded, so this controller falls
    # back to Spree::Admin::BaseController, which brings the inherited
    # `set_locale` before_action. Skip it so `set_login_locale` is the only
    # locale setter under test — matching production, where the Devise parent
    # has no such before_action.
    skip_before_action :set_locale, raise: false

    def show
      render plain: "#{I18n.locale}/#{Mobility.locale}"
    end
  end

  before do
    routes.draw { get 'show' => 'spree/admin/user_sessions#show' }
    @request.env['devise.mapping'] = Devise.mappings.values.first if defined?(Devise)
    allow(Spree).to receive(:available_locales).and_return(%i[en de fr])
  end

  let(:cookie_key) { Spree::Admin::LocaleConcern::ADMIN_LOCALE_COOKIE }

  # Response body is "<I18n.locale>/<Mobility.locale>" — the UI locale and the
  # pinned content locale, so each test asserts the decoupling.
  let(:ui_locale) { response.body.split('/').first }
  let(:content_locale) { response.body.split('/').last }

  around do |example|
    original_i18n = I18n.locale
    original_mobility = Mobility.locale
    example.run
  ensure
    I18n.locale = original_i18n
    Mobility.locale = original_mobility
  end

  context 'with a supported ?locale= param' do
    it 'applies the UI locale and persists it to the cookie' do
      get :show, params: { locale: 'de' }
      expect(ui_locale).to eq('de')
      expect(response.cookies[cookie_key.to_s]).to eq('de')
    end

    it "keeps the content locale (Mobility) on the store's content locale" do
      get :show, params: { locale: 'de' }
      expect(content_locale).not_to eq('de')
    end
  end

  context 'with an unsupported ?locale= param' do
    it 'ignores it' do
      get :show, params: { locale: 'pl' }
      expect(ui_locale).not_to eq('pl')
      expect(response.cookies[cookie_key.to_s]).to be_nil
    end

    it 'falls back to a valid cookie rather than shadowing it' do
      request.cookies[cookie_key.to_s] = 'fr'
      get :show, params: { locale: 'pl' }
      expect(ui_locale).to eq('fr')
    end
  end

  context 'with the cookie already set and no param (post-redirect into the session)' do
    it 'applies the cookie locale' do
      request.cookies[cookie_key.to_s] = 'fr'
      get :show
      expect(ui_locale).to eq('fr')
    end
  end

  context 'with no param and no cookie' do
    it 'renders the application default locale even when the thread carries a stale one' do
      # Server threads are reused across requests; without an explicit
      # assignment the login screen would render in whatever locale the
      # previous request on this thread happened to set.
      I18n.locale = :fr
      get :show
      expect(ui_locale).to eq(I18n.default_locale.to_s)
    end
  end
end
