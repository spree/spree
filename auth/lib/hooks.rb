class SpreeStaticContentHooks < Spree::ThemeSupport::HookListener

  replace :admin_login_navigation_bar, :partial => "layouts/admin/login_nav"
  replace :shared_login_bar, :partial => "shared/login_bar"
  insert_after :checkout_shipping_address, :partial => "checkout/save_user_addresses"

end
