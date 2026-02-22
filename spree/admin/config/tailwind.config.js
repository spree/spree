// Tailwind CSS v4 - Minimal config for content paths only
// Theme configuration has been moved to app/assets/tailwind/spree/admin/application.css
module.exports = {
  content: [
    // Host app admin customizations
    './app/helpers/spree/admin/**/*.rb',
    './app/javascript/spree/admin/**/*.js',
    './app/views/spree/admin/**/*.erb',
    // Spree Admin engine paths (set by engine initializer)
    process.env.SPREE_ADMIN_PATH + '/app/helpers/**/*.rb',
    process.env.SPREE_ADMIN_PATH + '/app/javascript/**/*.js',
    process.env.SPREE_ADMIN_PATH + '/app/views/spree/admin/**/*.erb'
  ].filter(Boolean)
}
