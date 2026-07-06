# Legacy Rails admin UI disabled — use React SPA dashboard instead.
# All admin functionality is now available through the new React dashboard
# (`packages/dashboard/`) + Admin API v3 (`spree/api/`).
#
# This gem remains for:
# - Admin API v3 endpoints (mounted in spree/api/config/routes.rb)
# - Shared models, services, concerns, and business logic
# - Email templates (spree/emails)
#
# The routes below are disabled. To re-enable the legacy Rails UI for
# backwards-compatibility, uncomment the Spree::Core::Engine.add_routes block
# and remove this comment.

