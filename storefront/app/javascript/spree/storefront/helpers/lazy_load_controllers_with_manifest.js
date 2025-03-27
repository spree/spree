const controllerAttribute = "data-controller"

// This function is based on `lazyLoadControllersFrom` function from Stimulus.
// https://github.com/hotwired/stimulus-rails/blob/main/app/assets/javascripts/stimulus-loading.js
// We need to slightly modify it to fit our needs, mostly to make allow list of controllers to be loaded and to use manifest when controller is not in the controllers directory.
// More information about what is `manifest` and what are `controllers` can be found in the `application.js` file.

export function lazyLoadControllersFromManifest(controllers, under, application, manifest = {}, element = document) {
  lazyLoadExistingControllers(controllers, under, application, manifest, element)
  lazyLoadNewControllers(controllers, under, application, manifest, element)
}

function lazyLoadExistingControllers(controllers, under, application, manifest, element) {
  queryControllerNamesWithin(element).forEach(controllerName => {
    if (controllers.includes(controllerName)) {
      loadController(controllerName, under, application, manifest)
    }
  }
  )
}

function lazyLoadNewControllers(controllers, under, application, manifest, element) {
  new MutationObserver((mutationsList) => {
    for (const { attributeName, target, type } of mutationsList) {
      switch (type) {
        case "attributes": {
          if (attributeName == controllerAttribute && target.getAttribute(controllerAttribute)) {
            extractControllerNamesFrom(target).forEach(controllerName => {
              if (controllers.includes(controllerName)) {
                loadController(controllerName, under, application, manifest)
              }
            }
            )
          }
          break;
        }

        case "childList": {
          lazyLoadExistingControllers(controllers, under, application, manifest, target)
          break;
        }
      }
    }
  }).observe(element, { attributeFilter: [controllerAttribute], subtree: true, childList: true })
}

function queryControllerNamesWithin(element) {
  return Array.from(element.querySelectorAll(`[${controllerAttribute}]`)).map(extractControllerNamesFrom).flat()
}

function extractControllerNamesFrom(element) {
  return element.getAttribute(controllerAttribute).split(/\s+/).filter(content => content.length)
}

function loadController(name, under, application, manifest) {
  if (canRegisterController(name, application)) {
    import(controllerFilename(name, under, manifest))
      .then(module => registerController(name, module, application))
      .catch(error => console.error(`Failed to autoload controller: ${name}`, error))
  }
}

function controllerFilename(name, under, manifest) {
  if (manifest && manifest[name]) {
    return manifest[name]
  }
  return `${under}/${name.replace(/--/g, "/").replace(/-/g, "_")}_controller`
}

function registerController(name, module, application) {
  if (canRegisterController(name, application)) {
    application.register(name, module.default)
  }
}

function canRegisterController(name, application) {
  return !application.router.modulesByIdentifier.has(name)
}