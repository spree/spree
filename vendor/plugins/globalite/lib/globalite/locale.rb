class Locale
  attr_reader :language, :country, :code

  #
  def self.language
    Globalite.language
  end

  # Return the country
  def self.country
    Globalite.country
  end

  # Return the user's locale or the system's if the user doesn't have one set
  def self.code
    "#{Globalite.language}-#{Globalite.country}".to_sym
  end
  
  #
  def self.set_code(locale)
    if locale.to_s.split('-') && locale.to_s.length.between?(4,5) && Globalite.locales.include?(locale.to_sym) 
       Globalite.language = locale.to_s.split('-')[0].downcase.to_sym if locale.to_s.split('-')[0]
       Globalite.country = locale.to_s.split('-')[1].upcase.to_sym if locale.to_s.split('-')[1]
    end
  end
  
  def self.code=(locale)
    self.set_code(locale)
  end
  
  # Return the available locales
  def self.codes
    Globalite.locales
  end
  
  # Return the locale name in its own language for instance fr-FR => Français
  def self.name(locale)
    Globalite.locale_name(locale)
  end
  
  # Return the list of the UI locales with their name
  def self.ui_locales
    Globalite.ui_locales
  end
  
  # Return the list of the Rails locales with their name 
  def self.rails_locales
    Globalite.rails_locales
  end

  # Reset the Locale to the default settings
  def self.reset!
    Locale.set_code("#{Globalite.default_language}-#{Globalite.default_country}")
  end
  
end
