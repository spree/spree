module Spree
  module Locales
    # Canonical set of locale codes a merchant may translate **data** into
    # (Mobility-backed content such as product names, descriptions, taxons,
    # option values, etc.).
    #
    # This is deliberately **independent of the languages Spree ships
    # translations for** (`Spree.available_locales`). In a headless setup the
    # storefront ships its own UI translations, so the languages a merchant can
    # store content in must not be constrained by Spree's own translations.
    #
    # Codes follow BCP-47 casing (lowercase language, uppercase region —
    # `pt-BR`, `zh-CN`) so the browser's `Intl.DisplayNames` resolves a clean
    # localized label for each. The list is the full ISO 639-1 base-language set
    # plus the regional variants that matter for commerce (British vs. US
    # English, Brazilian vs. European Portuguese, Simplified vs. Traditional
    # Chinese, etc.).
    #
    # Markets and stores only accept codes from this list when their locales
    # change, so an order's or cart's locale (which must be one its store
    # supports) is one too, unless the store kept a value saved before that.
    ALL = %w[
      aa ab ae af ak am an ar as av ay az
      ba be bg bh bi bm bn bo br bs
      ca ce ch co cr cs cu cv cy
      da de de-AT de-CH dv dz
      ee el en en-AU en-CA en-GB en-IN en-NZ en-US eo es es-419 es-CL es-EC es-MX et eu
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
      sa sc sd se sg si sk sl sl-SI sm sn so sq sr ss st su sv sw
      ta te tg th ti tk tl tn to tr ts tt tw ty
      ug uk ur uz
      ve vi vo
      wa wo
      xh
      yi yo
      za zh-CN zh-HK zh-TW zu
    ].freeze

    # The codes in a comma-separated list that are not listed, for a
    # validation to name.
    #
    # @param codes [String, nil] e.g. "en,pt-BR"
    # @return [Array<String>]
    def self.unlisted(codes)
      codes.to_s.split(',').map(&:strip).reject(&:empty?) - ALL
    end

    # A listed locale for a code from elsewhere (a host app's I18n config, a
    # country's official language, a legacy column): the listed spelling of
    # the code itself (`en_US` and `pt-br` give `en-US` and `pt-BR`),
    # otherwise the listed one for its language (`en-IE` gives `en`, `zh`
    # gives `zh-CN`), or nil when Spree knows neither.
    #
    # @param code [String, Symbol, nil]
    # @return [String, nil]
    def self.listed(code)
      code = code.to_s.strip.tr('_', '-')
      return if code.empty?

      ALL.find { |listed| listed.casecmp?(code) } || for_language(code.split('-').first)
    end

    # The listed locale for an ISO 639-1 language: the language itself, or
    # its first regional variant when only those are listed (`zh` gives
    # `zh-CN`).
    #
    # @param language [String]
    # @return [String, nil]
    def self.for_language(language)
      Spree.locale_for_language(language.to_s.downcase, ALL)
    end
  end
end
