pin 'application-spree-admin', to: 'spree/admin/application.js', preload: false

pin '@rails/actioncable', to: 'actioncable.esm.js', preload: ['application-spree-admin']
pin '@rails/activestorage', to: 'activestorage.esm.js', preload: ['application-spree-admin']
pin '@rails/actiontext', to: '@rails--actiontext--app--assets--javascripts--actiontext.js.js', preload: ['application-spree-admin']
pin 'trix', to: 'trix@2.1.12.js', preload: ['application-spree-admin']

pin '@rails/request.js', to: '@rails--request.js.js', preload: ['application-spree-admin'] # @0.0.8
pin 'sortablejs', preload: ['application-spree-admin'] # @1.15.6
pin 'chartkick', to: 'chartkick.js', preload: ['application-spree-admin']
pin 'Chart.bundle', to: 'Chart.bundle.js', preload: ['application-spree-admin']
pin 'local-time', preload: ['application-spree-admin'] # @3.0.2
pin 'mapkick/bundle', to: 'mapkick.bundle.js', preload: ['application-spree-admin']
pin "jquery", to: 'jquery.min.js', preload: ['application-spree-admin'] # @3.7.1
pin 'bootstrap', to: 'bootstrap--dist--js--bootstrap.bundle.min.js.js', preload: ['application-spree-admin'] # @4.6.1
pin 'dompurify', preload: ['application-spree-admin'] # @3.2.3

# Stimulus components
pin '@stimulus-components/auto-submit', to: '@stimulus-components--auto-submit.js', preload: ['application-spree-admin'] # @6.0.0
pin '@stimulus-components/rails-nested-form', to: '@stimulus-components--rails-nested-form.js', preload: ['application-spree-admin'] # @5.0.0
pin 'stimulus-notification', preload: ['application-spree-admin'] # @2.2.0
pin 'stimulus-password-visibility', preload: ['application-spree-admin'] # @2.1.1
pin 'stimulus-sortable', preload: ['application-spree-admin'] # @4.1.1
pin 'stimulus-textarea-autogrow', preload: ['application-spree-admin'] # @4.1.0
pin 'hotkeys-js', preload: ['application-spree-admin'] # @3.13.9
pin 'stimulus-use', preload: ['application-spree-admin'] # @0.51.3
pin 'stimulus-checkbox-select-all', preload: ['application-spree-admin'] # @5.3.0
pin 'stimulus-clipboard', preload: ['application-spree-admin'] # @4.0.1
#

# Uppy
# Uppy can't be downloaded, it has many relative imports in the code, and importmaps don't handle them, leaving us with broken imports.
pin '@uppy/core', to: 'https://ga.jspm.io/npm:@uppy/core@4.4.1/lib/index.js', preload: ['application-spree-admin']
pin '@uppy/dashboard', to: 'https://ga.jspm.io/npm:@uppy/dashboard@4.3.1/lib/index.js', preload: ['application-spree-admin']
pin '@uppy/image-editor', to: 'https://ga.jspm.io/npm:@uppy/image-editor@3.3.1/lib/index.js', preload: ['application-spree-admin']
pin '@transloadit/prettier-bytes',
    to: 'https://ga.jspm.io/npm:@transloadit/prettier-bytes@0.3.5/dist/prettierBytes.js',
    preload: ['application-spree-admin']
pin '@uppy/informer', to: 'https://ga.jspm.io/npm:@uppy/informer@4.2.1/lib/index.js', preload: ['application-spree-admin']
pin '@uppy/provider-views', to: 'https://ga.jspm.io/npm:@uppy/provider-views@4.4.1/lib/index.js', preload: ['application-spree-admin']
pin '@uppy/status-bar', to: 'https://ga.jspm.io/npm:@uppy/status-bar@4.1.1/lib/index.js', preload: ['application-spree-admin']
pin '@uppy/store-default', to: 'https://ga.jspm.io/npm:@uppy/store-default@4.2.0/lib/index.js', preload: ['application-spree-admin']
pin '@uppy/thumbnail-generator', to: 'https://ga.jspm.io/npm:@uppy/thumbnail-generator@4.1.1/lib/index.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/FOCUSABLE_ELEMENTS', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/FOCUSABLE_ELEMENTS.js',
                                          preload: ['application-spree-admin']
pin '@uppy/utils/lib/Translator', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/Translator.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/VirtualList', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/VirtualList.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/dataURItoBlob', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/dataURItoBlob.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/emaFilter', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/emaFilter.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/findAllDOMElements',
    to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/findAllDOMElements.js',
    preload: ['application-spree-admin']
pin '@uppy/utils/lib/findDOMElement', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/findDOMElement.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/generateFileID', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/generateFileID.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/getDroppedFiles',
    to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getDroppedFiles/index.js',
    preload: ['application-spree-admin']
pin '@uppy/utils/lib/getFileNameAndExtension',
    to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getFileNameAndExtension.js',
    preload: ['application-spree-admin']
pin '@uppy/utils/lib/getFileType', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getFileType.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/getTextDirection', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getTextDirection.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/getTimeStamp', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/getTimeStamp.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/isDragDropSupported',
    to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/isDragDropSupported.js',
    preload: ['application-spree-admin']
pin '@uppy/utils/lib/isObjectURL', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/isObjectURL.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/isPreviewSupported',
    to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/isPreviewSupported.js',
    preload: ['application-spree-admin']
pin '@uppy/utils/lib/prettyETA', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/prettyETA.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/remoteFileObjToLocal',
    to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/remoteFileObjToLocal.js',
    preload: ['application-spree-admin']
pin '@uppy/utils/lib/toArray', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/toArray.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/truncateString', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/truncateString.js', preload: ['application-spree-admin']
pin 'classnames', to: 'https://ga.jspm.io/npm:classnames@2.5.1/index.js', preload: ['application-spree-admin']
pin 'cropperjs', to: 'https://ga.jspm.io/npm:cropperjs@1.6.2/dist/cropper.js', preload: ['application-spree-admin']
pin 'eventemitter3', to: 'https://ga.jspm.io/npm:eventemitter3@5.0.1/index.mjs', preload: ['application-spree-admin']
pin 'exifr/dist/mini.esm.mjs', to: 'https://ga.jspm.io/npm:exifr@7.1.3/dist/mini.esm.mjs', preload: ['application-spree-admin']
pin 'lodash/', to: 'https://ga.jspm.io/npm:lodash@4.17.21/', preload: ['application-spree-admin']
pin 'memoize-one', to: 'https://ga.jspm.io/npm:memoize-one@6.0.0/dist/memoize-one.esm.js', preload: ['application-spree-admin']
pin 'mime-match', to: 'https://ga.jspm.io/npm:mime-match@1.0.2/index.js', preload: ['application-spree-admin']
pin 'namespace-emitter', to: 'https://ga.jspm.io/npm:namespace-emitter@2.0.1/index.js', preload: ['application-spree-admin']
pin 'nanoid/non-secure', to: 'https://ga.jspm.io/npm:nanoid@5.0.9/non-secure/index.js', preload: ['application-spree-admin']
pin 'p-queue', to: 'https://ga.jspm.io/npm:p-queue@8.0.1/dist/index.js', preload: ['application-spree-admin']
pin 'p-timeout', to: 'https://ga.jspm.io/npm:p-timeout@6.1.4/index.js', preload: ['application-spree-admin']
pin 'preact', to: 'https://ga.jspm.io/npm:preact@10.25.4/dist/preact.module.js', preload: ['application-spree-admin']
pin 'preact/hooks', to: 'https://ga.jspm.io/npm:preact@10.25.4/hooks/dist/hooks.module.js', preload: ['application-spree-admin']
pin 'shallow-equal', to: 'https://ga.jspm.io/npm:shallow-equal@3.1.0/dist/index.modern.mjs', preload: ['application-spree-admin']
pin 'wildcard', to: 'https://ga.jspm.io/npm:wildcard@1.1.2/index.js', preload: ['application-spree-admin']
pin '@paralleldrive/cuid2', to: 'https://ga.jspm.io/npm:@paralleldrive/cuid2@2.2.2/index.js', preload: ['application-spree-admin']
pin '@uppy/core/lib/BasePlugin.js', to: 'https://ga.jspm.io/npm:@uppy/core@4.4.1/lib/BasePlugin.js', preload: ['application-spree-admin']
pin '@uppy/utils/lib/RateLimitedQueue', to: 'https://ga.jspm.io/npm:@uppy/utils@6.1.1/lib/RateLimitedQueue.js', preload: ['application-spree-admin']
pin '@noble/hashes/crypto', to: 'https://ga.jspm.io/npm:@noble/hashes@1.7.1/crypto.js', preload: ['application-spree-admin']
pin '@noble/hashes/sha3', to: 'https://ga.jspm.io/npm:@noble/hashes@1.7.1/sha3.js', preload: ['application-spree-admin']

# Tom Select
# Same as Uppy, Tom Select can't be downloaded, it has many relative imports in the code, and importmaps don't handle them, leaving us with broken imports.
pin 'tom-select/dist/esm/tom-select.complete.js',
    to: 'https://ga.jspm.io/npm:tom-select@2.4.1/dist/esm/tom-select.complete.js',
    preload: ['application-spree-admin']
pin '@orchidjs/sifter', to: 'https://ga.jspm.io/npm:@orchidjs/sifter@1.1.0/dist/esm/sifter.js', preload: ['application-spree-admin']
pin '@orchidjs/unicode-variants',
    to: 'https://ga.jspm.io/npm:@orchidjs/unicode-variants@1.1.2/dist/esm/index.js',
    preload: ['application-spree-admin']

# Easepick
pin '@easepick/core',
    to: '@easepick--core.js',
    preload: ['application-spree-admin'] # @1.2.1
pin '@easepick/preset-plugin',
    to: '@easepick--preset-plugin.js',
    preload: ['application-spree-admin'] # @1.2.1
pin '@easepick/range-plugin',
    to: '@easepick--range-plugin.js',
    preload: ['application-spree-admin'] # @1.2.1
pin '@easepick/base-plugin',
    to: '@easepick--base-plugin.js',
    preload: ['application-spree-admin'] # @1.2.1
pin '@easepick/datetime',
    to: '@easepick--datetime.js',
    preload: ['application-spree-admin'] # @1.2.1
#

pin '@simonwep/pickr',
    to: '@simonwep--pickr.js',
    preload: ['application-spree-admin'] # @1.9.1

pin_all_from Spree::Admin::Engine.root.join('app/javascript/spree/admin/controllers'),
             under: 'spree/admin/controllers',
             to: 'spree/admin/controllers',
             preload: ['application-spree-admin']
pin_all_from Spree::Admin::Engine.root.join('app/javascript/spree/admin/helpers'),
             under: 'spree/admin/helpers',
             to: 'spree/admin/helpers',
             preload: ['application-spree-admin']
