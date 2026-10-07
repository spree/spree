# Fails a spec when code looks up a translation key that does not exist, so a
# typo or a key removed too eagerly is caught instead of rendering
# "Translation missing" text. Required by Spree's own spec helpers only.
I18n.exception_handler = lambda do |exception, *|
  raise exception.respond_to?(:to_exception) ? exception.to_exception : exception
end
