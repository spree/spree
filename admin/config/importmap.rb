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

# Stimulus components
pin "@stimulus-components/auto-submit", to: "https://ga.jspm.io/npm:@stimulus-components/auto-submit@6.0.0/dist/stimulus-auto-submit.mjs", preload: false
pin "@stimulus-components/rails-nested-form", to: "https://ga.jspm.io/npm:@stimulus-components/rails-nested-form@5.0.0/dist/stimulus-rails-nested-form.mjs", preload: false
pin "stimulus-notification", to: "https://ga.jspm.io/npm:stimulus-notification@2.2.0/dist/stimulus-notification.mjs", preload: false
pin "stimulus-password-visibility", to: "https://ga.jspm.io/npm:stimulus-password-visibility@2.1.1/dist/stimulus-password-visibility.mjs", preload: false
pin "stimulus-reveal-controller", to: "https://ga.jspm.io/npm:stimulus-reveal-controller@4.1.0/dist/stimulus-reveal-controller.mjs", preload: false
pin "stimulus-sortable", to: "https://ga.jspm.io/npm:stimulus-sortable@4.1.1/dist/stimulus-sortable.mjs", preload: false
pin "stimulus-textarea-autogrow", to: "https://ga.jspm.io/npm:stimulus-textarea-autogrow@4.1.0/dist/stimulus-textarea-autogrow.mjs", preload: false
pin "tailwindcss-stimulus-components", to: "https://ga.jspm.io/npm:tailwindcss-stimulus-components@6.1.3/dist/tailwindcss-stimulus-components.module.js", preload: false
pin "hotkeys-js", to: "https://ga.jspm.io/npm:hotkeys-js@3.13.9/dist/hotkeys.esm.js", preload: false
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.6/modular/sortable.esm.js", preload: false
pin "stimulus-use", to: "https://ga.jspm.io/npm:stimulus-use@0.51.3/dist/index.js", preload: false
pin "stimulus-checkbox-select-all", to: "https://ga.jspm.io/npm:stimulus-checkbox-select-all@5.3.0/dist/stimulus-checkbox-select-all.mjs", preload: false
pin "stimulus-clipboard", to: "https://ga.jspm.io/npm:stimulus-clipboard@4.0.1/dist/stimulus-clipboard.mjs", preload: false
#

#Uppy
pin "@uppy/core", to: "https://ga.jspm.io/npm:@uppy/core@4.4.1/lib/index.js",preload: false
pin "@uppy/dashboard", to: "https://ga.jspm.io/npm:@uppy/dashboard@4.3.1/lib/index.js",preload: false
pin "@uppy/image-editor", to: "https://ga.jspm.io/npm:@uppy/image-editor@3.3.1/lib/index.js",preload: false
pin "@transloadit/prettier-bytes", to: "https://ga.jspm.io/npm:@transloadit/prettier-bytes@0.3.5/dist/prettierBytes.js",preload: false
pin "@uppy/informer", to: "https://ga.jspm.io/npm:@uppy/informer@4.2.1/lib/index.js",preload: false
pin "@uppy/provider-views", to: "https://ga.jspm.io/npm:@uppy/provider-views@4.4.1/lib/index.js",preload: false
pin "@uppy/status-bar", to: "https://ga.jspm.io/npm:@uppy/status-bar@4.1.1/lib/index.js",preload: false
pin "@uppy/store-default", to: "https://ga.jspm.io/npm:@uppy/store-default@4.2.0/lib/index.js",preload: false
pin "@uppy/thumbnail-generator", to: "https://ga.jspm.io/npm:@uppy/thumbnail-generator@4.1.1/lib/index.js",preload: false
pin "@uppy/utils/lib/FOCUSABLE_ELEMENTS", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/FOCUSABLE_ELEMENTS.js",preload: false
pin "@uppy/utils/lib/Translator", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/Translator.js",preload: false
pin "@uppy/utils/lib/VirtualList", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/VirtualList.js",preload: false
pin "@uppy/utils/lib/dataURItoBlob", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/dataURItoBlob.js",preload: false
pin "@uppy/utils/lib/emaFilter", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/emaFilter.js",preload: false
pin "@uppy/utils/lib/findAllDOMElements", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/findAllDOMElements.js",preload: false
pin "@uppy/utils/lib/findDOMElement", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/findDOMElement.js",preload: false
pin "@uppy/utils/lib/generateFileID", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/generateFileID.js",preload: false
pin "@uppy/utils/lib/getDroppedFiles", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getDroppedFiles/index.js",preload: false
pin "@uppy/utils/lib/getFileNameAndExtension", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getFileNameAndExtension.js",preload: false
pin "@uppy/utils/lib/getFileType", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getFileType.js",preload: false
pin "@uppy/utils/lib/getTextDirection", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getTextDirection.js",preload: false
pin "@uppy/utils/lib/getTimeStamp", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getTimeStamp.js",preload: false
pin "@uppy/utils/lib/isDragDropSupported", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/isDragDropSupported.js",preload: false
pin "@uppy/utils/lib/isObjectURL", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/isObjectURL.js",preload: false
pin "@uppy/utils/lib/isPreviewSupported", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/isPreviewSupported.js",preload: false
pin "@uppy/utils/lib/prettyETA", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/prettyETA.js",preload: false
pin "@uppy/utils/lib/remoteFileObjToLocal", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/remoteFileObjToLocal.js",preload: false
pin "@uppy/utils/lib/toArray", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/toArray.js",preload: false
pin "@uppy/utils/lib/truncateString", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/truncateString.js",preload: false
pin "classnames", to: "https://ga.jspm.io/npm:classnames@2.5.1/index.js",preload: false
pin "cropperjs", to: "https://ga.jspm.io/npm:cropperjs@1.6.2/dist/cropper.js",preload: false
pin "eventemitter3", to: "https://ga.jspm.io/npm:eventemitter3@5.0.1/index.mjs",preload: false
pin "exifr/dist/mini.esm.mjs", to: "https://ga.jspm.io/npm:exifr@7.1.3/dist/mini.esm.mjs",preload: false
pin "lodash/", to: "https://ga.jspm.io/npm:lodash@4.17.21/",preload: false
pin "memoize-one", to: "https://ga.jspm.io/npm:memoize-one@6.0.0/dist/memoize-one.esm.js",preload: false
pin "mime-match", to: "https://ga.jspm.io/npm:mime-match@1.0.2/index.js",preload: false
pin "namespace-emitter", to: "https://ga.jspm.io/npm:namespace-emitter@2.0.1/index.js",preload: false
pin "nanoid/non-secure", to: "https://ga.jspm.io/npm:nanoid@5.0.9/non-secure/index.js",preload: false
pin "p-queue", to: "https://ga.jspm.io/npm:p-queue@8.0.1/dist/index.js",preload: false
pin "p-timeout", to: "https://ga.jspm.io/npm:p-timeout@6.1.4/index.js",preload: false
pin "preact", to: "https://ga.jspm.io/npm:preact@10.25.4/dist/preact.module.js",preload: false
pin "preact/hooks", to: "https://ga.jspm.io/npm:preact@10.25.4/hooks/dist/hooks.module.js",preload: false
pin "shallow-equal", to: "https://ga.jspm.io/npm:shallow-equal@3.1.0/dist/index.modern.mjs",preload: false
pin "wildcard", to: "https://ga.jspm.io/npm:wildcard@1.1.2/index.js", preload: false
pin "@paralleldrive/cuid2", to: "https://ga.jspm.io/npm:@paralleldrive/cuid2@2.2.2/index.js", preload: false
pin "@uppy/core/lib/BasePlugin.js", to: "https://ga.jspm.io/npm:@uppy/core@4.4.1/lib/BasePlugin.js", preload: false
pin "@uppy/utils/lib/RateLimitedQueue", to: "https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/RateLimitedQueue.js", preload: false
pin "@noble/hashes/crypto", to: "https://ga.jspm.io/npm:@noble/hashes@1.7.1/crypto.js", preload: false
pin "@noble/hashes/sha3", to: "https://ga.jspm.io/npm:@noble/hashes@1.7.1/sha3.js", preload: false
#

#Tom Select
pin "tom-select/dist/esm/tom-select.complete.js", to: "https://ga.jspm.io/npm:tom-select@2.4.1/dist/esm/tom-select.complete.js",preload: false
pin "@orchidjs/sifter", to: "https://ga.jspm.io/npm:@orchidjs/sifter@1.1.0/dist/esm/sifter.js", preload: false
pin "@orchidjs/unicode-variants", to: "https://ga.jspm.io/npm:@orchidjs/unicode-variants@1.1.2/dist/esm/index.js", preload: false
#

# Easepick
pin "@easepick/core", to: "https://ga.jspm.io/npm:@easepick/core@1.2.1/dist/index.esm.js", preload: false
pin "@easepick/preset-plugin", to: "https://ga.jspm.io/npm:@easepick/preset-plugin@1.2.1/dist/index.esm.js", preload: false
pin "@easepick/range-plugin", to: "https://ga.jspm.io/npm:@easepick/range-plugin@1.2.1/dist/index.esm.js", preload: false
pin "@easepick/base-plugin", to: "https://ga.jspm.io/npm:@easepick/base-plugin@1.2.1/dist/index.esm.js", preload: false
pin "@easepick/datetime", to: "https://ga.jspm.io/npm:@easepick/datetime@1.2.1/dist/index.esm.js", preload: false
#


pin "@simonwep/pickr", to: "https://ga.jspm.io/npm:@simonwep/pickr@1.9.1/dist/pickr.min.js", preload: false

pin_all_from Spree::Admin::Engine.root.join("app/javascript/spree/admin/controllers"), under: "spree/admin/controllers", to: "spree/admin/controllers", preload: ["application-spree-admin"]
pin_all_from Spree::Admin::Engine.root.join("app/javascript/spree/admin/helpers"), under: "spree/admin/helpers", to: "spree/admin/helpers", preload: ["application-spree-admin"]
