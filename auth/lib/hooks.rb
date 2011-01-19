class SpreeStaticContentHooks < Spree::ThemeSupport::HookListener

  replace :admin_login_navigation_bar, :partial => "layouts/admin/login_nav"

end
