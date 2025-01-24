pin "application-spree-admin", to: "spree/admin/application.js"

pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: ["application-spree-admin"]
pin "@rails/actioncable", to: "actioncable.esm.js", preload: ["application-spree-admin"]
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: ["application-spree-admin"]
pin "@rails/activestorage", to: "activestorage.esm.js", preload: ["application-spree-admin"]
pin "@rails/actiontext", to: "https://ga.jspm.io/npm:@rails/actiontext@7.0.4/app/assets/javascripts/actiontext.js", preload: ["application-spree-admin"]
#https://github.com/rails/requestjs-rails/issues/5#issuecomment-1017936902
pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.11/src/index.js", preload: ["application-spree-admin"]
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.2/modular/sortable.esm.js", preload: ["application-spree-admin"]
pin "chartkick", to: "chartkick.js", preload: ["application-spree-admin"]
pin "Chart.bundle", to: "Chart.bundle.js", preload: ["application-spree-admin"]
pin "local-time", to: "https://ga.jspm.io/npm:local-time@3.0.2/app/assets/javascripts/local-time.es2017-esm.js", preload: ["application-spree-admin"]
pin "mapkick/bundle", to: "mapkick.bundle.js", preload: ["application-spree-admin"]
pin 'jquery', to: 'jquery3.min.js', preload: ["application-spree-admin"]
# Bootstrap 4 does not want to work with importmaps, after long debugging I found this comment which helped https://github.com/twbs/bootstrap-rubygem/issues/257#issuecomment-1707196465. Bootstrap has to be imported from jsdelivr.
pin "bootstrap", to: 'https://cdn.jsdelivr.net/npm/bootstrap@4.6.1/dist/js/bootstrap.bundle.min.js', preload: ["application-spree-admin"]
pin "@stimulus-components/auto-submit", to: "https://ga.jspm.io/npm:@stimulus-components/auto-submit@6.0.0/dist/stimulus-auto-submit.mjs", preload: ["application-spree-admin"]
pin "@stimulus-components/rails-nested-form", to: "https://ga.jspm.io/npm:@stimulus-components/rails-nested-form@5.0.0/dist/stimulus-rails-nested-form.mjs", preload: ["application-spree-admin"]
pin "stimulus-notification", to: "https://ga.jspm.io/npm:stimulus-notification@2.2.0/dist/stimulus-notification.mjs", preload: ["application-spree-admin"]
pin "stimulus-password-visibility", to: "https://ga.jspm.io/npm:stimulus-password-visibility@2.1.1/dist/stimulus-password-visibility.mjs", preload: ["application-spree-admin"]
pin "stimulus-reveal-controller", to: "https://ga.jspm.io/npm:stimulus-reveal-controller@4.1.0/dist/stimulus-reveal-controller.mjs", preload: ["application-spree-admin"]
pin "stimulus-sortable", to: "https://ga.jspm.io/npm:stimulus-sortable@4.1.1/dist/stimulus-sortable.mjs", preload: ["application-spree-admin"]
pin "stimulus-textarea-autogrow", to: "https://ga.jspm.io/npm:stimulus-textarea-autogrow@4.1.0/dist/stimulus-textarea-autogrow.mjs", preload: ["application-spree-admin"]
pin "tailwindcss-stimulus-components", to: "https://ga.jspm.io/npm:tailwindcss-stimulus-components@6.1.3/dist/tailwindcss-stimulus-components.module.js", preload: ["application-spree-admin"]
pin "hotkeys-js", to: "https://ga.jspm.io/npm:hotkeys-js@3.13.9/dist/hotkeys.esm.js", preload: ["application-spree-admin"]
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.6/modular/sortable.esm.js", preload: ["application-spree-admin"]
pin "stimulus-use", to: "https://ga.jspm.io/npm:stimulus-use@0.51.3/dist/index.js", preload: ["application-spree-admin"]


pin_all_from Spree::Admin::Engine.root.join("app/javascript/spree/admin/controllers"), under: "spree/admin/controllers", to: "spree/admin/controllers", preload: ["application-spree-admin"]
pin_all_from Spree::Admin::Engine.root.join("app/javascript/spree/admin/helpers"), under: "spree/admin/helpers", to: "spree/admin/helpers", preload: ["application-spree-admin"]
