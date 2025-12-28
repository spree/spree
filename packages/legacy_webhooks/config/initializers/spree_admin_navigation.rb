Rails.application.config.after_initialize do
  developers_tabs_nav = Spree.admin.navigation.developers_tabs

  developers_tabs_nav.add :webhooks,
                          label: "#{Spree.t(:webhooks)} (Legacy))",
                          url: :admin_webhooks_subscribers_path,
                          position: 20,
                          active: -> { controller_name == 'webhooks_subscribers' },
                          if: -> { can?(:manage, Spree::Webhooks::Subscriber) }
end
