# Shared dependencies between storefront and admin
pin 'tailwindcss-stimulus-components', preload: ['application-spree-storefront', 'application-spree-admin'] # @3.0.4
pin 'stimulus-reveal-controller', preload: ['application-spree-storefront', 'application-spree-admin'] # @4.1.0

pin_all_from Spree::Core::Engine.root.join('app/javascript/spree/core/controllers'),
             under: 'spree/core/controllers',
             to: 'spree/core/controllers',
             preload: ['application-spree-storefront', 'application-spree-admin']
pin_all_from Spree::Core::Engine.root.join('app/javascript/spree/core/helpers'),
             under: 'spree/core/helpers',
             to: 'spree/core/helpers',
             preload: ['application-spree-storefront', 'application-spree-admin']
