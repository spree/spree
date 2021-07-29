require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Store
  include Spree::Core::ControllerHelpers::Locale
end

class FakesControllerWithLocale < FakesController
  def config_locale
    'en'
  end
end

describe Spree::Core::ControllerHelpers::Locale, type: :controller do
  controller(FakesController) {}

  describe '#current_locale' do
    context 'store with locale set' do
      let!(:store) { create :store, default: true, default_locale: 'fr', supported_locales: 'fr,de' }

      it 'returns current store default locale' do
        expect(controller.current_locale.to_s).to eq('fr')
      end

      it 'return supported locale when passed as param' do
        controller.params = { locale: 'de' }
        expect(controller.current_locale.to_s).to eq('de')
      end
    end

    context 'config_locale present' do
      controller(FakesControllerWithLocale) {}

      let!(:store) { create :store, default: true, default_locale: 'fr' }

      it 'returns config_locale if present' do
        expect(controller.current_locale.to_s).to eq('en')
      end
    end

    context 'store without locale set' do
      let!(:store) { create :store, default: true, default_locale: nil }

      context 'without I18n.default_locale set' do
        it 'fallbacks to english' do
          expect(controller.current_locale.to_s).to eq('en')
        end
      end

      context 'with I18n.default_locale set' do
        before { I18n.default_locale = :de }

        after { I18n.default_locale = :en }

        it 'fallbacks to the default application locale' do
          expect(controller.current_locale.to_s).to eq('de')
        end
      end
    end
  end

  describe '#supported_locales' do
    let!(:store) { create :store, default: true, default_locale: 'de' }

    it 'returns supported currencies' do
      expect(controller.supported_locales.to_s).to include('de')
    end
  end

  describe '#locale_param' do
    let!(:store) { create :store, default: true, default_locale: 'en', supported_locales: 'en,de,fr' }

    context 'same as store default locale' do
      before { I18n.locale = :en }

      it { expect(controller.locale_param).to eq(nil) }
    end

    context 'different than store locale' do
      before { I18n.locale = :de }

      after { I18n.locale = :en }

      it { expect(controller.locale_param).to eq('de') }
    end
  end
end
