# Page Builder Admin Navigation Configuration
# This file defines the storefront/page builder navigation for Spree Admin

Rails.application.config.after_initialize do
  # ===============================================
  # Sidebar Navigation
  # ===============================================
  sidebar_nav = Spree.admin.navigation.sidebar

  # Storefront with submenu
  sidebar_nav.add :storefront,
          label: 'admin.storefront',
          url: :admin_themes_path,
          icon: 'building-store',
          position: 65,
          if: -> { can?(:manage, Spree::Theme) } do |storefront|

    # Pages
    storefront.add :pages,
                  label: :pages,
                  url: :admin_pages_path,
                  position: 20,
                  if: -> { can?(:manage, Spree::Page) }

    # Storefront Settings
    storefront.add :storefront_settings,
                  label: :settings,
                  url: :edit_admin_storefront_path,
                  position: 40,
                  if: -> { can?(:manage, current_store) }
  end

  # ===============================================
  # Settings Navigation
  # ===============================================
  settings_nav = Spree.admin.navigation.settings

  # Checkout
  settings_nav.add :checkout,
          label: :checkout,
          url: -> { spree.edit_admin_store_path(section: 'checkout') },
          icon: 'shopping-cart',
          position: 50,
          active: -> { controller_name == 'stores' && params[:section] == 'checkout' },
          if: -> { can?(:manage, current_store) }
end
