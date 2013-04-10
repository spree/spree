#= require jsuri
class window.Spree
  @ready: (callback) ->
    jQuery(document).ready(callback)

  # Helper function to take a URL and add query parameters to it
  # Uses the JSUri library from here: https://code.google.com/p/jsuri/
  # Thanks to Jake Moffat for the suggestion: https://twitter.com/jakeonrails/statuses/321776992221544449
  @url: (uri, query) ->
    uri = new Uri(uri)
    $.each query, (key, value) ->
      uri.addQueryParam(key, value)
    return uri
