require 'spec_helper'

class ReplyToProbeMailer < Spree::BaseMailer
  def sample
    mail(to: 'probe@example.com', from: 'from@example.com', subject: 'probe', body: 'body')
  end
end

describe Spree::BaseMailer, type: :mailer do
  let!(:store) { @default_store }

  describe '#set_email_locale (deprecated)' do
    subject(:mailer) { described_class.new }

    before do
      store.update!(default_locale: 'de')
      allow(mailer).to receive(:current_store).and_return(store)
    end
    after { I18n.locale = :en }

    it 'emits a deprecation warning' do
      expect(Spree::Deprecation).to receive(:warn).with(/set_email_locale is deprecated/)
      mailer.set_email_locale
    end

    it 'still sets I18n.locale from the store default for backwards compatibility' do
      allow(Spree::Deprecation).to receive(:warn)
      I18n.locale = :en
      mailer.set_email_locale
      expect(I18n.locale).to eq(:de)
    end
  end

  describe '#reply_to_address' do
    subject(:mailer) { described_class.new }

    before { allow(mailer).to receive(:current_store).and_return(store) }

    context 'when the store has a customer support email' do
      let(:store) { create(:store, customer_support_email: 'support@example.com', mail_from_address: 'no-reply@example.com') }

      it 'returns the customer support email' do
        expect(mailer.reply_to_address).to eq('support@example.com')
      end
    end

    context 'when the customer support email is blank' do
      let(:store) { create(:store, customer_support_email: '', mail_from_address: 'no-reply@example.com') }

      it 'falls back to the mail from address' do
        expect(mailer.reply_to_address).to eq('no-reply@example.com')
      end
    end
  end

  describe 'default Reply-To header' do
    let!(:store) { @default_store }

    it 'is applied without the mailer passing reply_to explicitly' do
      expect(ReplyToProbeMailer.sample.reply_to).to eq([store.customer_support_email])
    end
  end

  describe '#with_store_locale' do
    subject(:mailer) { described_class.new }

    before do
      I18n.enforce_available_locales = false
      store.update!(name: 'Acme', default_locale: 'en')
    end
    after { I18n.enforce_available_locales = true }

    it 'renders the block in the given locale' do
      captured = nil
      mailer.with_store_locale(store, 'de') { captured = I18n.locale }
      expect(captured).to eq(:de)
    end

    # Store#name is translatable; without the store fallbacks active (as in a
    # background job) it returns nil under a non-default locale, blanking the
    # footer. `with_store_locale` activates those fallbacks like a request does.
    it 'activates store translation fallbacks so translatable attributes are not blank' do
      resolved = mailer.with_store_locale(store, 'de') { store.name }
      expect(resolved).to eq('Acme')
    end

    it 'restores the previous locale and fallbacks afterwards' do
      I18n.locale = :en
      previous_fallbacks = Mobility.store_based_fallbacks
      mailer.with_store_locale(store, 'de') { :noop }
      expect(I18n.locale).to eq(:en)
      expect(Mobility.store_based_fallbacks).to equal(previous_fallbacks)
    end

    it 'defaults to the store default locale when none is given' do
      store.update!(default_locale: 'fr')
      captured = nil
      mailer.with_store_locale(store) { captured = I18n.locale }
      expect(captured).to eq(:fr)
    end

    # Regression: the early no-locale return must not touch the thread's
    # fallbacks — clobbering them to nil crashes every later translated read
    # on the same (worker) thread.
    it 'leaves the fallbacks untouched when no locale can be resolved' do
      previous_fallbacks = Mobility.store_based_fallbacks
      mailer.with_store_locale(nil) { :noop }
      expect(Mobility.store_based_fallbacks).to equal(previous_fallbacks)
    end
  end

  describe '#mail store locale fallback' do
    # Subclasses that call `mail` directly without `with_store_locale` — Devise
    # mailers, extensions — must still render in the store default locale, as
    # `mail` guaranteed before Spree 5.6 via `set_email_locale`.
    let(:probe_mailer) do
      stub_const('LocaleProbeMailer', Class.new(described_class) do
        cattr_accessor :captured_locale

        def plain_email
          mail(to: 'probe@example.com', from: 'probe@example.com', subject: 'probe') do |format|
            format.text do
              self.class.captured_locale = I18n.locale
              render plain: 'probe'
            end
          end
        end

        def wrapped_email
          with_store_locale(current_store, 'fr') do
            mail(to: 'probe@example.com', from: 'probe@example.com', subject: 'probe') do |format|
              format.text do
                self.class.captured_locale = I18n.locale
                render plain: 'probe'
              end
            end
          end
        end
      end)
    end

    before do
      I18n.enforce_available_locales = false
      store.update!(default_locale: 'de')
    end

    after do
      I18n.enforce_available_locales = true
      store.update!(default_locale: 'en')
    end

    it 'renders unwrapped mailers in the store default locale' do
      probe_mailer.plain_email.message
      expect(probe_mailer.captured_locale).to eq(:de)
    end

    it 'does not override an explicit with_store_locale wrapping' do
      probe_mailer.wrapped_email.message
      expect(probe_mailer.captured_locale).to eq(:fr)
    end
  end
end
