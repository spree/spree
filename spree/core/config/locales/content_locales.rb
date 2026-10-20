# A store's content locales are the codes Spree::Locales::ALL lists,
# independent of the languages anything has translation files for. An API
# request sets I18n.locale (and so Mobility's) to its content locale, and both
# refuse a locale I18n does not know, so this registers every listed code:
# content can be stored and read in, say, Yoruba, while messages in it fall
# back along the i18n fallback chain. The backend ignores a locale with no
# keys at all, hence the one marker key. An app that limits
# `config.i18n.available_locales` keeps its own list.
Spree::Locales::ALL.to_h { |code| [code.to_sym, { spree_content_locale: true }] }
