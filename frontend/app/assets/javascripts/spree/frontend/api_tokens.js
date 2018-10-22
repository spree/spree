Spree.fetchApiTokens = function () {
  fetch(Spree.routes.api_tokens, {
    method: 'GET',
    credentials: 'same-origin'
  }).then(response => {
    switch (response.status) {
      case 200:
        response.json().then(json => {
          Spree.orderToken = json.order_token,
          Spree.oauthToken = json.oauth_token
        })
        break
    }
  })
}

Spree.ready(function () { Spree.fetchApiTokens() })
