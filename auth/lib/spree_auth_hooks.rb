class SpreeAuthHooks < Spree::ThemeSupport::HookListener

  replace :admin_login_navigation_bar, :partial => "layouts/admin/login_nav"
  replace :shared_login_bar, :partial => "shared/login_bar"

end
