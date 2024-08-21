pin "application-spree-admin", to: "spree/admin/application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@rails/request.js", to: "requestjs.js", preload: true
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.2/modular/sortable.esm.js"

pin_all_from Spree::Admin::Engine.root.join("app/javascript/spree/admin/controllers"), under: "controllers", to: "spree/admin/controllers"
pin_all_from Spree::Admin::Engine.root.join("app/javascript/spree/admin/helpers"), under: "helpers", to: "spree/admin/helpers"
