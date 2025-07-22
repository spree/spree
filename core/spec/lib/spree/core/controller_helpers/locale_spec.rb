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

  let(:user) { build(:user, selected_locale: 'pl') }

  before { allow(controller).to receive(:spree_current_user).and_return(user) }

  describe '#current_locale' do
    context 'taking locale from user and store with locale set' do
      before { allow(Spree::Config).to receive(:use_user_locale).and_return(true) }

      let!(:store) { create :store, default: true, default_locale: 'fr', supported_locales: 'fr,de,pl' }

      it 'returns locale set within user' do
        expect(controller.current_locale.to_s).to eq('pl')
      end
    end

    context 'not taking locale from user' do
      before { allow(Spree::Config).to receive(:use_user_locale).and_return(false) }

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
          before do
            allow(I18n).to receive(:default_locale).and_return(:de)
          end

          it 'fallbacks to the default application locale' do
            expect(controller.current_locale.to_s).to eq('de')
          end
        end
      end
    end
  end

  describe '#supported_locales' do
    let!(:store) { create :store, default: true, default_locale: 'de', supported_locales: 'de, pl' }

    it 'returns supported currencies' do
      expect(controller.supported_locales.to_s).to include('de')
    end

    it 'returns supported locales' do
      expect(controller.supported_locales.to_s).to include('pl')
    end
  end

  describe '#locale_param' do
    let!(:store) { create :store, default: true, default_locale: 'en', supported_locales: 'en,de,fr' }

    context 'same as store default locale' do
      before do
        allow(I18n).to receive(:locale).and_return(:en)
      end

      it { expect(controller.locale_param).to eq(nil) }
    end

    context 'different than store locale' do
      before do
        allow(I18n).to receive(:locale).and_return(:de)
      end

      it { expect(controller.locale_param).to eq('de') }
    end
  end

  describe '#set_locale' do
    subject(:set_locale) { controller.set_locale }

    let!(:store) { create :store, default: true, default_locale: 'de', supported_locales: 'en,pl,de' }

    before do
      I18n.default_locale = :en
      I18n.locale = :en
    end

    after do
      I18n.default_locale = :en
      I18n.locale = :en
    end

    it 'sets the default and the current locale' do
      set_locale

      expect(I18n.default_locale).to eq(:de)
      expect(I18n.locale).to eq(:pl)
    end

    context 'when always using translations' do
      before do
        allow(Spree::Config).to receive(:always_use_translations).and_return(true)
      end

      it 'sets only the current locale' do
        set_locale

        expect(I18n.default_locale).to eq(:en)
        expect(I18n.locale).to eq(:pl)
      end
    end
  end
end
