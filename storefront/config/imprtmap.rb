pin "application-spree-storefront", to: "spree/storefront/application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@rails/request.js", to: "requestjs.js", preload: true

pin_all_from Spree::Storefront::Engine.root.join("app/javascript/spree/storefront/controllers"), under: "controllers", to: "spree/storefront/controllers"
pin_all_from Spree::Storefront::Engine.root.join("app/javascript/spree/storefront/helpers"), under: "helpers", to: "spree/storefront/helpers"
