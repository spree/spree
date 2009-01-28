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
    if session[:locale]
      I18n.locale = session[:locale]
    elsif logged_in?
      I18n.locale = current_user.preferred_locale
    else
      I18n.locale = Spree::Config[:default_locale]
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
