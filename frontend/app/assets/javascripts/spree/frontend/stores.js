Spree.fetchStores = function () {
  return $.ajax({
    url: Spree.pathFor('stores_link')
  }).done(function (data) {
    Spree.stooresFetched = true
    return $('#link-to-stores').html(data)
  })
}

Spree.ready(function () {
  if (!Spree.storesFetched) Spree.fetchStores()
})
