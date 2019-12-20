Spree.pathFor = function (path) {
  var locationOrigin = (window.location.protocol + '//' + window.location.hostname) + (window.location.port ? ':' + window.location.port : '')
  return this.url('' + locationOrigin + (this.mountedAt()) + Spree.locale + "/" + path, this.url_params).toString()
}
