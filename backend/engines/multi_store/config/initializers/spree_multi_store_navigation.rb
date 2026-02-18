Rails.application.config.after_initialize do
  next unless defined?(Spree::Admin)

  settings_nav = Spree.admin.navigation.settings

  # Domains
  settings_nav.add :domains,
          label: :domains,
          url: :admin_custom_domains_path,
          icon: 'world-www',
          position: 60,
          active: -> { controller_name == 'custom_domains' },
          if: -> { can?(:manage, Spree::CustomDomain) }
end
