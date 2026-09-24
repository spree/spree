require 'spec_helper'

describe Spree::AdminUserMailer, type: :mailer do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user, email: 'admin@example.com') }
  let(:token) { 'secret-reset-token' }

  before do
    allow(Spree::Stores::DashboardUrl).to receive(:without_store_fallback).with(store: store).and_return('https://admin.example.com')
  end

  describe '#password_reset_email' do
    it 'sends to the admin with the store-prefixed subject' do
      message = described_class.password_reset_email(admin_user, token, store)

      expect(message.to).to eq(['admin@example.com'])
      expect(message.subject).to eq("#{store.name} #{Spree.t('admin_user_mailer.password_reset_email.subject')}")
    end

    it 'links with the reset token' do
      message = described_class.password_reset_email(admin_user, token, store)

      expect(message.body.encoded).to include("token=#{token}")
    end

    it 'prefers the redirect URL when the API validated one (dashboard SPA)' do
      message = described_class.password_reset_email(admin_user, token, store, redirect_url: 'https://admin.example.com/reset-password')

      expect(message.body.encoded).to include("https://admin.example.com/reset-password?token=#{token}")
    end

    it 'falls back to the dashboard reset page, not the store URL' do
      message = described_class.password_reset_email(admin_user, token, store)

      expect(message.body.encoded).to include("https://admin.example.com/reset-password?token=#{token}")
    end

    it 'sends nothing and logs what to configure when the dashboard address is unknown' do
      allow(Spree::Stores::DashboardUrl).to receive(:without_store_fallback).with(store: store).and_return(nil)
      allow(Rails.logger).to receive(:error)

      expect { described_class.password_reset_email(admin_user, token, store).deliver_now }.
        not_to change { ActionMailer::Base.deliveries.count }
      expect(Rails.logger).to have_received(:error).with(/SPREE_DASHBOARD_URL/)
    end

    context 'in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('production'))
        allow(Rails.logger).to receive(:error)
      end

      it 'sends the email when the reset link is https' do
        expect { described_class.password_reset_email(admin_user, token, store).deliver_now }.
          to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it 'sends nothing and logs what to fix when the reset link is not a full https address' do
        allow(Spree::Stores::DashboardUrl).to receive(:without_store_fallback).with(store: store).and_return('http://admin.example.com', 'https:admin.example.com')

        expect { described_class.password_reset_email(admin_user, token, store).deliver_now }.
          not_to change { ActionMailer::Base.deliveries.count }

        expect { described_class.password_reset_email(admin_user, token, store).deliver_now }.
          not_to change { ActionMailer::Base.deliveries.count }
        expect(Rails.logger).to have_received(:error).with(/not https/).twice
      end
    end

    context 'when the admin has a dashboard language set' do
      around do |example|
        previous = I18n.available_locales
        I18n.available_locales = previous | [:pl]
        I18n.backend.store_translations(
          :pl,
          spree: { admin_user_mailer: { password_reset_email: { subject: 'Instrukcja resetu hasła' } } }
        )
        example.run
      ensure
        I18n.available_locales = previous
        I18n.backend.reload!
      end

      # @default_store is shared across the suite — examples that set its
      # admin locale must put it back or they leak into later examples.
      after do
        store.preferred_admin_locale = nil
        store.save!
      end

      it 'renders in the admin selected locale instead of the store default' do
        admin_user.update!(selected_locale: 'pl')

        message = described_class.password_reset_email(admin_user, token, store)

        expect(message.subject).to eq("#{store.name} Instrukcja resetu hasła")
      end

      it 'falls back to the store admin locale when the admin has none' do
        store.preferred_admin_locale = 'pl'
        store.save!

        message = described_class.password_reset_email(admin_user, token, store)

        expect(message.subject).to eq("#{store.name} Instrukcja resetu hasła")
      end

      it 'prefers the admin selected locale over the store admin locale' do
        store.preferred_admin_locale = 'pl'
        store.save!
        admin_user.update!(selected_locale: 'en')

        message = described_class.password_reset_email(admin_user, token, store)

        expect(message.subject).to eq("#{store.name} #{Spree.t('admin_user_mailer.password_reset_email.subject', locale: :en)}")
      end

      it 'falls back to the store default locale for blank or unavailable values' do
        admin_user.update!(selected_locale: 'xx')

        message = described_class.password_reset_email(admin_user, token, store)

        expect(message.subject).to eq("#{store.name} #{Spree.t('admin_user_mailer.password_reset_email.subject')}")
      end
    end
  end
end
