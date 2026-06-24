module Spree
  module Locales
    # Canonical set of locale codes a merchant may translate **data** into
    # (Mobility-backed content such as product names, descriptions, taxons,
    # option values, etc.).
    #
    # This is deliberately **independent of the admin/storefront UI translation
    # set** (`Spree.available_locales`, which reflects which `spree_i18n` UI
    # bundles happen to be installed). In a headless setup the storefront ships
    # its own UI translations, so the languages a merchant can store content in
    # must not be constrained by which admin chrome translations exist.
    #
    # Codes follow BCP-47 casing (lowercase language, uppercase region —
    # `pt-BR`, `zh-CN`) so the browser's `Intl.DisplayNames` resolves a clean
    # localized label for each. The list is the full ISO 639-1 base-language set
    # plus the regional variants that matter for commerce (British vs. US
    # English, Brazilian vs. European Portuguese, Simplified vs. Traditional
    # Chinese, etc.).
    #
    # The underlying translation tables accept any locale string, so this list
    # governs only what the locale pickers offer — it is not a hard storage
    # constraint.
    ALL = %w[
      aa ab ae af ak am an ar as av ay az
      ba be bg bh bi bm bn bo br bs
      ca ce ch co cr cs cu cv cy
      da de de-AT de-CH dv dz
      ee el en en-AU en-CA en-GB en-IN en-NZ eo es es-419 es-MX et eu
      fa ff fi fj fo fr fr-CA fy
      ga gd gl gn gu gv
      ha he hi ho hr ht hu hy hz
      ia id ie ig ii ik io is it iu
      ja jv
      ka kg ki kj kk kl km kn ko kr ks ku kv kw ky
      la lb lg li ln lo lt lu lv
      mg mh mi mk ml mn mr ms mt my
      na nb nd ne ng nl nn no nr nv ny
      oc oj om or os
      pa pi pl ps pt pt-BR pt-PT
      qu
      rm rn ro ru rw
      sa sc sd se sg si sk sl sm sn so sq sr ss st su sv sw
      ta te tg th ti tk tl tn to tr ts tt tw ty
      ug uk ur uz
      ve vi vo
      wa wo
      xh
      yi yo
      za zh-CN zh-HK zh-TW zu
    ].freeze
  end
end
