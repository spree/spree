class ApiHooks < Spree::ThemeSupport::HookListener
  insert_after :admin_user_edit_form, :partial => "admin/users/api_fields"
end
