Spree.fetchAccount = function () {
  return $.ajax({
    url: Spree.pathFor('account_link')
  }).done(function (data) {
    return $('#link-to-account').html(data)
  })
}

Spree.ready(function () { Spree.fetchAccount() })
