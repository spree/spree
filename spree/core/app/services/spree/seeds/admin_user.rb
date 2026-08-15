module Spree
  module Seeds
    # Creates the first admin user — but only when ADMIN_EMAIL and
    # ADMIN_PASSWORD are both explicitly set (CI, worktrees, scripted
    # installs). Without them, no dummy account is minted: a one-time setup
    # token is generated instead and the printed setup URL claims the
    # installation through the dashboard's first-run screen
    # (docs/plans/6.0-store-context-and-first-run-setup.md).
    class AdminUser
      prepend Spree::ServiceModule::Base

      def call
        return if Spree.admin_user_class.blank?
        return unless Spree.admin_user_class.count.zero?

        if ENV['ADMIN_EMAIL'].present? && ENV['ADMIN_PASSWORD'].present?
          create_admin_from_env
        else
          announce_setup_url
        end
      end

      private

      def create_admin_from_env
        user = Spree.admin_user_class.create!(
          email: ENV['ADMIN_EMAIL'],
          password: ENV['ADMIN_PASSWORD'],
          password_confirmation: ENV['ADMIN_PASSWORD'],
          first_name: ENV.fetch('ADMIN_FIRST_NAME', 'Spree'),
          last_name: ENV.fetch('ADMIN_LAST_NAME', 'Admin')
        )

        store = Spree::Store.default
        return unless store&.persisted?

        store.add_user(user)
        provision_store_defaults(store)
      end

      # This install never sees the setup screen, so the country question is
      # answered by the environment instead — defaulting to the US, which is
      # what these installs got when the seeds hardcoded it.
      def provision_store_defaults(store)
        country = Spree::Country.by_iso(ENV.fetch('STORE_COUNTRY', 'US')) || Spree::Country.by_iso('US')

        Spree::Stores::ProvisionDefaults.call(
          store: store,
          country: country,
          locale: ENV['STORE_LOCALE'].presence,
          currency: ENV['STORE_CURRENCY'].presence
        )
      end

      # The setup token lives on the default store (has_secure_token, set at
      # creation), so a repeated `db:seed` reprints the same URL. Stores
      # predating the column get one generated here.
      def announce_setup_url
        store = Spree::Store.default
        return if store.nil? || !store.persisted?

        store.regenerate_setup_token if store.setup_token.blank?

        message = <<~MSG

          ==> No admin account yet. Start your app, then open this link to
              create the first admin account:

              #{store.setup_url}

              (Run `bin/rails spree:setup:token` to print it again.)

        MSG

        # The URL goes to stdout only — the token is a claim-this-installation
        # credential, and Rails.logger typically feeds a log aggregator with a
        # far wider audience than the person running the seed.
        puts message unless Rails.env.test?
        Rails.logger&.info('No admin account yet — run `bin/rails spree:setup:token` to print the setup link.')
      end
    end
  end
end
