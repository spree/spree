module Spree
  module AnalyticsHelper

    def spree_analytics
      render :partial => 'analytics/header'
    end

    def analytics_tags
      tags = { :id => Spree::Dash::Config.site_id.to_s }
      tags.merge! product_analytics_tags
      tags.merge! taxon_analytics_tags
      tags.merge! keywords_analytics_tags
      tags.merge! cart_analytics_tags
      tags.merge! completed_analytics_tags
    end

    def product_analytics_tags
      return {} unless @product
      { :product => { :name => @product.name,
                      :price => @product.price,
                      :sku => @product.sku,
                      :categories => @product.taxons.map { |t| t.permalink }
                    }
      }
    end

    def taxon_analytics_tags
      return {} unless @taxon
      { :category => { :name => @taxon.permalink } }
    end

    def keywords_analytics_tags
      return {} unless params[:keywords]
      { :search => { :keyword => params[:keywords] } }
    end

    def cart_analytics_tags
      return {} unless @order and @order.cart?
      { :cart => { :total => @order.total,
                   :products => products_for_order }
      }
    end

    def completed_analytics_tags
      return {} unless @order and @order.complete?
      { :confirm => { :orderid => @order.number,
                      :total => @order.total,
                      :shipping => @order.ship_total,
                      :tax => @order.tax_total,
                      :discount => @order.adjustment_total,
                      :subtotal => @order.item_total,
                      :products => products_for_order }
      }
    end

    def products_for_order
      @order.line_items.map do |line_item|
        variant = line_item.variant
        { :name => variant.name,
          :qty => line_item.quantity,
          :price => variant.price,
          :sku => variant.sku,
          :categories => variant.product.taxons.map { |t| t.permalink }
        }
      end
    end

    CURRENCIES = [
          ["Australian Dollar", "AUD"],
          ["New Zealand Dollar", "NZD"],
          ["US Dollar", "USD"],
          ["Euro", "EUR"],
          ["British Pound", "GBP"],
          ["Japanese Yen", "JPY"],
          ["Afghanistan Afghani", "AFA"],
          ["Albanian Lek", "ALL"],
          ["Algerian Dinar", "DZD"],
          ["Andorran Franc", "ADF"],
          ["Andorran Peseta", "ADP"],
          ["Angolan New Kwanza", "AON"],
          ["Argentine Peso", "ARS"],
          ["Aruban Florin", "AWG"],
          ["Austrian Schilling", "ATS"],
          ["Bahamanian Dollar", "BSD"],
          ["Bahraini Dinar", "BHD"],
          ["Bangladeshi Taka", "BDT"],
          ["Barbados Dollar", "BBD"],
          ["Belgian Franc", "BEF"],
          ["Belize Dollar", "BZD"],
          ["Bermudian Dollar", "BMD"],
          ["Bhutan Ngultrum", "BTN"],
          ["Bolivian Boliviano", "BOB"],
          ["Botswana Pula", "BWP"],
          ["Brazilian Real", "BRL"],
          ["Brunei Dollar", "BND"],
          ["Bulgarian Lev", "BGL"],
          ["Burundi Franc", "BIF"],
          ["CFA Franc BCEAO", "XOF"],
          ["CFA Franc BEAC", "XAF"],
          ["Cambodian Riel", "KHR"],
          ["Canadian Dollar", "CAD"],
          ["Cape Verde Escudo", "CVE"],
          ["Cayman Islands Dollar", "KYD"],
          ["Central Pacific Franc", "CFP"],
          ["Chilean Peso", "CLP"],
          ["Chinese Yuan Renminbi", "CNY"],
          ["Colombian Peso", "COP"],
          ["Comoros Franc", "KMF"],
          ["Costa Rican Colon", "CRC"],
          ["Croatian Kuna", "HRK"],
          ["Cuban Peso", "CUP"],
          ["Cyprus Pound", "CYP"],
          ["Czech Koruna", "CSK"],
          ["Danish Krone", "DKK"],
          ["Djibouti Franc", "DJF"],
          ["Dominican R. Peso", "DOP"],
          ["Dutch Guilder", "NLG"],
          ["ECU", "XEU"],
          ["East Caribbean Dollar", "XCD"],
          ["Ecuador Sucre", "ECS"],
          ["Egyptian Pound", "EGP"],
          ["El Salvador Colon", "SVC"],
          ["Estonian Kroon", "EEK"],
          ["Ethiopian Birr", "ETB"],
          ["Falkland Islands Pound", "FKP"],
          ["Fiji Dollar", "FJD"],
          ["Finnish Markka", "FIM"],
          ["French Franc", "FRF"],
          ["Gambian Dalasi", "GMD"],
          ["German Mark", "DEM"],
          ["Ghanaian Cedi", "GHC"],
          ["Gibraltar Pound", "GIP"],
          ["Greek Drachma", "GRD"],
          ["Guatemalan Quetzal", "GTQ"],
          ["Guinea Franc", "GNF"],
          ["Guyanese Dollar", "GYD"],
          ["Haitian Gourde", "HTG"],
          ["Honduran Lempira", "HNL"],
          ["Hong Kong Dollar", "HKD"],
          ["Hungarian Forint", "HUF"],
          ["Iceland Krona", "ISK"],
          ["Indian Rupee", "INR"],
          ["Indonesian Rupiah", "IDR"],
          ["Iranian Rial", "IRR"],
          ["Iraqi Dinar", "IQD"],
          ["Irish Punt", "IEP"],
          ["Israeli New Shekel", "ILS"],
          ["Italian Lira", "ITL"],
          ["Jamaican Dollar", "JMD"],
          ["Jordanian Dinar", "JOD"],
          ["Kazakhstan Tenge", "KZT"],
          ["Kenyan Shilling", "KES"],
          ["Kuwaiti Dinar", "KWD"],
          ["Lao Kip", "LAK"],
          ["Latvian Lats", "LVL"],
          ["Lebanese Pound", "LBP"],
          ["Lesotho Loti", "LSL"],
          ["Liberian Dollar", "LRD"],
          ["Libyan Dinar", "LYD"],
          ["Lithuanian Litas", "LTL"],
          ["Luxembourg Franc", "LUF"],
          ["Macau Pataca", "MOP"],
          ["Malagasy Franc", "MGF"],
          ["Malawi Kwacha", "MWK"],
          ["Malaysian Ringgit", "MYR"],
          ["Maldive Rufiyaa", "MVR"],
          ["Maltese Lira", "MTL"],
          ["Mauritanian Ouguiya", "MRO"],
          ["Mauritius Rupee", "MUR"],
          ["Mexican Peso", "MXP"],
          ["Mongolian Tugrik", "MNT"],
          ["Moroccan Dirham", "MAD"],
          ["Mozambique Metical", "MZM"],
          ["Myanmar Kyat", "MMK"],
          ["NL Antillian Guilder", "ANG"],
          ["Namibia Dollar", "NAD"],
          ["Nepalese Rupee", "NPR"],
          ["Nicaraguan Cordoba Oro", "NIO"],
          ["Nigerian Naira", "NGN"],
          ["North Korean Won", "KPW"],
          ["Norwegian Kroner", "NOK"],
          ["Omani Rial", "OMR"],
          ["Pakistan Rupee", "PKR"],
          ["Panamanian Balboa", "PAB"],
          ["Papua New Guinea Kina", "PGK"],
          ["Paraguay Guarani", "PYG"],
          ["Peruvian Nuevo Sol", "PEN"],
          ["Philippine Peso", "PHP"],
          ["Polish Zloty", "PLZ"],
          ["Portuguese Escudo", "PTE"],
          ["Qatari Rial", "QAR"],
          ["Romanian Leu", "ROL"],
          ["Russian Rouble", "RUB"],
          ["Samoan Tala", "WST"],
          ["Sao Tome/Principe Dobra", "STD"],
          ["Saudi Riyal", "SAR"],
          ["Seychelles Rupee", "SCR"],
          ["Sierra Leone Leone", "SLL"],
          ["Singapore Dollar", "SGD"],
          ["Slovak Koruna", "SKK"],
          ["Slovenian Tolar", "SIT"],
          ["Solomon Islands Dollar", "SBD"],
          ["Somali Shilling", "SOS"],
          ["South African Rand", "ZAR"],
          ["South-Korean Won", "KRW"],
          ["Spanish Peseta", "ESP"],
          ["Sri Lanka Rupee", "LKR"],
          ["St. Helena Pound", "SHP"],
          ["Sudanese Dinar", "SDD"],
          ["Sudanese Pound", "SDP"],
          ["Suriname Guilder", "SRG"],
          ["Swaziland Lilangeni", "SZL"],
          ["Swedish Krona", "SEK"],
          ["Swiss Franc", "CHF"],
          ["Syrian Pound", "SYP"],
          ["Taiwan Dollar", "TWD"],
          ["Tanzanian Shilling", "TZS"],
          ["Thai Baht", "THB"],
          ["Tonga Pa'anga", "TOP"],
          ["Trinidad/Tobago Dollar", "TTD"],
          ["Tunisian Dinar", "TND"],
          ["Turkish Lira", "TRL"],
          ["Uganda Shilling", "UGS"],
          ["Ukraine Hryvnia", "UAH"],
          ["Uruguayan Peso", "UYP"],
          ["Utd. Arab Emir. Dirham", "AED"],
          ["Vanuatu Vatu", "VUV"],
          ["Venezuelan Bolivar", "VEB"],
          ["Vietnamese Dong", "VND"],
          ["Yugoslav Dinar", "YUN"],
          ["Zambian Kwacha", "ZMK"],
          ["ZWD","Zimbabwe Dollar"]
        ]
  end
end
