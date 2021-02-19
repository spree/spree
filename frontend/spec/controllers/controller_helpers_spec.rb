require 'spec_helper'

# In this file, we want to test that the controller helpers function correctly
# So we need to use one of the controllers inside Spree.
# ProductsController is good.
describe Spree::ProductsController, type: :controller do
  let!(:supported_locales) { [:en, :de] }
  let!(:available_locale) { :de }
  let!(:unavailable_locale) { :ru }

  before do
    I18n.enforce_available_locales = false
  end

  after do
    Spree::Frontend::Config[:locale] = :en
    Rails.application.config.i18n.default_locale = :en
    I18n.locale = :en
    I18n.enforce_available_locales = true
  end

  # Regression test for #1184
  context 'when session locale not set' do
    before do
      session[:locale] = nil
    end

    context 'when Spree::Frontend::Config[:locale] not present' do
      before do
        Spree::Frontend::Config[:locale] = nil
      end

      context 'when rails application default locale not set' do
        before do
          Rails.application.config.i18n.default_locale = nil
        end

        it 'sets the I18n default locale' do
          get :index
          expect(I18n.locale).to eq(I18n.default_locale)
        end
      end

      context 'when rails application default locale is set' do
        context 'and in available_locales' do
          before do
            Spree::Store.default.update(default_locale: nil, supported_locales: nil)
            Rails.application.config.i18n.default_locale = available_locale
          end

          it 'sets the rails app locale' do
            expect(I18n.locale).to eq(:en)
            get :index
            expect(I18n.locale).to eq(available_locale)
          end
        end
      end
    end

    context 'when Spree::Frontend::Config[:locale] is present' do
      context 'and not in available_locales' do
        before do
          Spree::Frontend::Config[:locale] = unavailable_locale
        end

        # FIXME: after adding supported_locales to Store this should be testable again
        xit 'sets the I18n default locale' do
          get :index
          expect(I18n.locale).to eq(I18n.default_locale)
        end
      end

      context 'and not in available_locales' do
        before do
          Spree::Frontend::Config[:locale] = available_locale
        end

        it 'sets the default locale based on Spree::Frontend::Config[:locale]' do
          expect(I18n.locale).to eq(:en)
          get :index
          expect(I18n.locale).to eq(available_locale)
        end
      end
    end
  end
end
