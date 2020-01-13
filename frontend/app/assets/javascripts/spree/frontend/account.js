Spree.fetchAccount = function () {
  return $.ajax({
    url: Spree.pathFor('account_link')
  }).done(function (data) {
    Spree.accountFetched = true
    return $('#link-to-account').html(data)
  })
}

Spree.ready(function () {
  if (!Spree.accountFetched) Spree.fetchAccount()
})
