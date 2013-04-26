#= require jsuri
class window.Spree
  @ready: (callback) ->
    jQuery(document).ready(callback)

  # Helper function to take a URL and add query parameters to it
  # Uses the JSUri library from here: https://code.google.com/p/jsuri/
  # Thanks to Jake Moffat for the suggestion: https://twitter.com/jakeonrails/statuses/321776992221544449
  @url: (uri, query) ->
    if uri.path == undefined
      uri = new Uri(uri)
    if query
      $.each query, (key, value) ->
        uri.addQueryParam(key, value)
    if Spree.api_key
      uri.addQueryParam('token', Spree.api_key)
    return uri

  # Helper method in case people want to call uri rather than url
  @uri: (uri, query) ->
    url(uri, query)

  # This function automatically appends the API token
  # for the user to the end of any URL.
  # Immediately after, this string is then passed to jQuery.ajax.
  #
  # ajax works in two ways in jQuery:
  #
  # $.ajax("url", {settings: 'go here'})
  # or:
  # $.ajax({url: "url", settings: 'go here'})
  #
  # This function will support both of these calls.
  @ajax: (url_or_settings, settings) ->
    if (typeof(url_or_settings) == "string")
      $.ajax(Spree.url(url_or_settings).toString(), settings)
    else
      url = url_or_settings['url']
      delete url_or_settings['url']
      $.ajax(Spree.url(url).toString(), url_or_settings)
