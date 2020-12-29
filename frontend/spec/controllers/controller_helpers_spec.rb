require 'spec_helper'

# In this file, we want to test that the controller helpers function correctly
# So we need to use one of the controllers inside Spree.
# ProductsController is good.
describe Spree::ProductsController, type: :controller do
  let!(:available_locales) { [:en, :de] }
  let!(:available_locale) { :de }
  let!(:unavailable_locale) { :ru }

  before do
    I18n.enforce_available_locales = false
    expect(I18n).to receive(:available_locales).and_return(available_locales)
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
        context 'and not in available_locales' do
          before do
            Rails.application.config.i18n.default_locale = unavailable_locale
          end

          it 'sets the I18n default locale' do
            get :index
            expect(I18n.locale).to eq(I18n.default_locale)
          end
        end

        context 'and in available_locales' do
          before do
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

        it 'sets the I18n default locale' do
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

  context 'when session locale is set' do
    context 'and not in available_locales' do
      before do
        session[:locale] = unavailable_locale
      end

      it 'sets the I18n default locale' do
        get :index
        expect(I18n.locale).to eq(I18n.default_locale)
      end
    end

    context 'and in available_locales' do
      before do
        session[:locale] = available_locale
      end

      it 'sets the session locale' do
        expect(I18n.locale).to eq(:en)
        get :index
        expect(I18n.locale).to eq(available_locale)
      end
    end
  end
end
