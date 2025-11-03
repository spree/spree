// Tailwind CSS v4 - Minimal config for content paths only
// Theme configuration has been moved to app/assets/tailwind/application.css
module.exports = {
  content: [
    'public/*.html',
    'app/helpers/**/*.rb',
    'app/javascript/**/*.js',
    'app/views/spree/**/*.erb',
    'app/views/devise/**/*.erb',
    'app/views/themes/**/*.erb',
    process.env.SPREE_STOREFRONT_PATH + '/app/helpers/**/*.rb',
    process.env.SPREE_STOREFRONT_PATH + '/app/javascript/**/*.js',
    process.env.SPREE_STOREFRONT_PATH + '/app/views/themes/**/*.erb',
    process.env.SPREE_STOREFRONT_PATH + '/app/views/spree/**/*.erb',
    process.env.SPREE_STOREFRONT_PATH + '/app/views/devise/**/*.erb'
  ]
}
