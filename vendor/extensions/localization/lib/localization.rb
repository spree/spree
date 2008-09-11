module Localization
    
  def self.included(base)
    return unless Spree::Config[:allow_locale_switching]
    base.class_eval {
      before_filter :set_locale
    }
  end

  private

  # Set the locale from the session, the current_user preferred locale
  # (defaults to 'en-US'), or the navigator. If none of these works,
  # the Globalite default locale is set (en-*)
  def set_locale
    # Try to get the locale from the session, from user preferred
    # locale, and then from the navigator
    #         if params[:locale]
    #        Locale.code = params[:locale]
    #     els
    if session[:locale]
      Locale.code = session[:locale]
    elsif logged_in?
      Locale.code = current_user.preferred_locale
    else
    # Temporarily commented out.  This was causing major performance problems (doubling the time of the request).
    # Replaced with a default locale based on an application preference.
      #Locale.code = local_case(get_valid_lang_from_accept_header)
      Locale.code = Spree::Config[:default_locale]
    end

    logger.debug "[globalite] Locale set to #{Locale.code}"
    # render the page
    # yield

    # reset the locale to its default value
    # Locale.reset!
  end

  # Get a sorted array of the navigator languages
  def get_sorted_langs_from_accept_header
    accept_langs = (request.env['HTTP_ACCEPT_LANGUAGE'] || "en-us,en;q=0.5").split(/,/) rescue nil
    return nil unless accept_langs

    # Extract langs and sort by weight
    # Example HTTP_ACCEPT_LANGUAGE: "en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3"
    wl = {}
    accept_langs.each {|accept_lang|
      if (accept_lang + ';q=1') =~ /^(.+?);q=([^;]+).*/
        wl[($2.to_f rescue -1.0)]= $1
      end
    }
    logger.debug "[globalite] client accepted locales: #{wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }.to_sentence}"
    sorted_langs = wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }
  end

  # Returns a valid language that best suits the HTTP_ACCEPT_LANGUAGE request header.
  # If no valid language can be deduced, then <tt>nil</tt> is returned.
  def get_valid_lang_from_accept_header
    # Get the sorted navigator languages and find the first one that matches our available languages
    get_sorted_langs_from_accept_header.detect{|l| get_matching_ui_locale(l) }
  end

  # Returns the UI locale that best matches with the parameter
  # or nil if not found
  def get_matching_ui_locale(locale)
    lang = locale[0,2].downcase

    # Check with exact matching
    if Globalite.ui_locales.values.include?(local_case(locale))
      local_case(locale)
    end

    # Check on the language only
    Globalite.ui_locales.values.each do |value|
      value.to_s =~ /#{lang}-*/ ? value : nil
    end
  end

  def local_case(l)
    if l[3,5]
      "#{l[0,2]}-#{l[3,5].upcase}".to_sym
    else
      "#{l[0,2]}-*".to_sym
    end
  end
  
  # can be used as a shortcut for translation
  def t(replacement_string = '__localization_missing__', override_key = nil) 
    (override_key || replacement_string.downcase.gsub(/\s/, "_").to_sym).l(replacement_string)
  end

end
