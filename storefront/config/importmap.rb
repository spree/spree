pin 'application-spree-storefront', to: 'spree/storefront/application.js', preload: false

pin 'stimulus-scroll-to', preload: ['application-spree-storefront'] # @4.1.0
pin 'stimulus-read-more', preload: ['application-spree-storefront'] # @4.1.0
pin '@kanety/stimulus-accordion', to: '@kanety--stimulus-accordion.js', preload: ['application-spree-storefront'] # @1.1.0
pin 'headroom.js', preload: ['application-spree-storefront'] # @0.12.0
pin 'photoswipe/lightbox', to: 'photoswipe--dist--photoswipe-lightbox.esm.js.js', preload: ['application-spree-storefront'] # @5.4.4
pin 'nouislider', preload: ['application-spree-storefront'] # @15.8.1
pin 'swiper/bundle', to: 'https://ga.jspm.io/npm:swiper@11.2.2/swiper-bundle.mjs', preload: ['application-spree-storefront'] # @11.2.2
pin '@stimulus-components/carousel', to: '@stimulus-components--carousel.js', preload: ['application-spree-storefront'] # @6.0.0
pin 'photoswipe', preload: false # @5.4.4
pin "card-validator", to: "card-validator.js", preload: ['application-spree-storefront'] # @10.0.2
pin "credit-card-type", to: "credit-card-type.js", preload: ['application-spree-storefront'] # @10.0.2

pin_all_from Spree::Storefront::Engine.root.join('app/javascript/spree/storefront/controllers'),
             under: 'spree/storefront/controllers',
             to: 'spree/storefront/controllers',
             preload: ['application-spree-storefront']
pin_all_from Spree::Storefront::Engine.root.join('app/javascript/spree/storefront/helpers'),
             under: 'spree/storefront/helpers',
             to: 'spree/storefront/helpers',
             preload: ['application-spree-storefront']
