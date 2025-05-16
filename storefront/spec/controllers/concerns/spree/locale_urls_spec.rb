require 'spec_helper'

module Spree
  RSpec.describe LocaleUrls, type: :controller do
    controller(ActionController::Base) do
      include Spree::LocaleUrls
      include Spree::Core::ControllerHelpers::Locale

      def index
        render plain: 'index'
      end
    end

    before do
      allow(controller).to receive(:current_store).and_return(@default_store)
      allow(controller).to receive(:current_locale).and_return('en')
      allow(controller).to receive(:currency_param).and_return(nil)
      allow(controller).to receive(:supported_locales).and_return(['en', 'fr', 'es'])
    end

    describe '#default_url_options' do
      context 'when current locale is the same as default store locale' do
        before do
          allow(controller).to receive(:current_locale).and_return('en')
          @default_store.update(default_locale: 'en')
        end

        it 'does not include locale in URL options' do
          expect(controller.send(:default_url_options)[:locale]).to be_nil
        end
      end

      context 'when current locale is different from default store locale' do
        before do
          allow(controller).to receive(:current_locale).and_return('fr')
          @default_store.update(default_locale: 'en')
        end

        it 'includes locale in URL options' do
          expect(controller.send(:default_url_options)[:locale]).to eq('fr')
        end
      end

      context 'when default_locale is nil' do
        before do
          allow(controller).to receive(:current_locale).and_return('fr')
          @default_store.update(default_locale: nil)
        end

        it 'does not include locale in URL options' do
          expect(controller.send(:default_url_options)[:locale]).to be_nil
        end
      end

      it 'includes currency in URL options' do
        allow(controller).to receive(:currency_param).and_return('USD')
        expect(controller.send(:default_url_options)[:currency]).to eq('USD')
      end
    end

    describe '#redirect_to_default_locale' do
      context 'when locale param is present but not supported' do
        it 'redirects to URL without locale' do
          allow(controller).to receive(:supported_locale?).with('xx').and_return(false)
          expect(controller).to receive(:url_for).with({ locale: nil, action: 'index', controller: 'anonymous' }).and_return('/anonymous/index')
          get :index, params: { locale: 'xx' }
          expect(response).to redirect_to('/anonymous/index')
        end
      end

      context 'when locale param is blank' do
        it 'does not redirect' do
          get :index
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when locale param is supported' do
        it 'does not redirect' do
          allow(controller).to receive(:supported_locale?).with('fr').and_return(true)
          get :index, params: { locale: 'fr' }
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
