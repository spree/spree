Rails.application.config.after_initialize do
  Spree.admin.partials.dashboard_sidebar << 'spree/admin/dashboard/store_preview'
end
