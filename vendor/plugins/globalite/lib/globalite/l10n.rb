module Globalite 

  module L10n
    
    @@default_language = :en
    attr_reader :default_language

    @@default_country = :*
    mattr_reader :default_country

    @@reserved_keys = [ :limit ]
    mattr_reader :reserved_keys

    @@languages = []
    def languages
      @@languages
    end

    def default_language
      @@default_language
    end

    @@countries = []
    def countries
      @@countries
    end

    @@locales = {}
    def locales
      @@locales.keys
    end

    @@rails_locales = {}
    def rails_locales
      @@rails_locales
    end

    @@ui_locales = {}
    def ui_locales
      @@ui_locales
    end

    @@current_language = nil
    def current_language
      @@current_language || default_language
    end
    alias :language :current_language

    @@current_country = nil
    def country
      @@current_country || default_country
    end
    alias :current_country :country 

    def current_locale
      "#{current_language}-#{current_country}".to_sym
    end
    alias :locale :current_locale

    # Set the current language ( ISO 639-1 language code in lowercase letters)
    # Usage:
    # Globalite.language = 'fr' or Globalite.language = :Fr
    # Will save the current language code if available, otherwise nada, switching back to the previous language
    #
    def language=(language)

      language = language.to_s.downcase.to_sym if language.class == Symbol
      language = language.downcase.to_sym if language.class == String && !language.empty?

      if @@languages.include?(language)
        @@current_language = language
        if !@@locales.include?("#{language}-#{@@current_country}".to_sym)
          @@current_country = :*
        end
      end

      #Locale.update_session_locale
      localize_rails
      @@current_language
    end
    alias :current_language= :language= 

    # Set the current country code (ISO 3166 country code in uppercase letters)
    # Usage:
    # Globalite.country = 'US' or Globalite.country = :fr
    # Will store the current country code if supported 
    # Will try to automatically find the language for your country
    # If the country isn't unknown to the system, the country will be set as :*
    #
    def country=(country)
      load_localization! if defined? RAILS_ENV && RAILS_ENV == 'development'
      country = country.to_s.upcase.to_sym if country.class == Symbol
      country = country.upcase.to_sym if country.class == String && !country.empty?

      if @@locales.include?("#{current_language}-#{country}".to_sym)
        @@current_country = country
      elsif locales.each {|locale| locale =~ /[a-z][a-z]-#{country.to_s}/ }
        locales.each do |key| 
          if key.to_s.include?(country.to_s)  
            @new_language = key.to_s.split('-')[0].downcase.to_sym
          end
        end
        if @new_language && @@locales.include?("#{@new_language}-#{country}".to_sym)
          @@current_language = @new_language 
          @@current_country = country 
        end
      else  
        @@current_country = :*
      end
      #Locale.update_session_locale
      @@current_country
    end
    alias :current_country= :country=

    def locale=(locale)
      Locale.set_code(locale)
    end
    alias :current_locale= :locale=

    @@localization_sources = []
    def add_localization_source(path)
      @@localization_sources << path
      load_localization!
    end

    def localization_sources
      @@localization_sources
    end

    # List localizations for the current locale
    def localizations 
      @@locales[Locale.code] || {} 
    end

    # Return the translation for the key, a string can be passed to replaced a missing translation
    def localize(key, error_msg='__localization_missing__', args={}, locale=nil)
      return if reserved_keys.include? key

      # Set a temporary Locale to support the localized_in method
      #
      unless locale.nil?
        @original_locale = Locale.code
        Locale.set_code(locale)
      end
      localized = localizations[key] || error_msg
      # Get translations from another country but in the same language if Globalite can't find a translation for my locale
      #
      if localized == error_msg
        locales.each do |t_locale|  
          if t_locale.to_s.include?("#{current_language.to_s}-") && t_locale != Locale.code
            localized =  @@locales[t_locale][key] || error_msg
          end  
        end
      end  
      localized = interpolate_string(localized.dup, args.dup) if localized.class == String && localized != error_msg
      
      # let's handle pluralization if needed
      # the translation must include pluralize{count, singular string} to be translated
      # the translator can also pass the plural form if needed:
      #    pluralize{3, goose, geese}
      localized = localized.gsub( /pluralize\{(.*)\}/){ |erb| pluralize(Regexp.last_match(1)) } if localized.is_a?(String) && (localized=~ /pluralize\{(.*)\}/)
      
      # Set the locale back to normal
      #
      unless locale.nil?
        Locale.code = @original_locale
      end
            
      return localized
    end
    alias :loc :localize

    def localize_with_args(key, args={})
      localize(key, '_localization missing_', args)
    end
    alias :l_with_args :localize_with_args

    def add_reserved_key(*key)
      (@@reserved_keys += key.flatten).uniq!
    end
    alias :add_reserved_keys :add_reserved_key

    # modified version of the Rails pluralize method from ActionView::Helpers::TextHelper module
    # TODO: load custom inflector based on the language one uses.
    def pluralize(l_string) #count, singular, plural = nil)
      # map the arguments like in the original pluralize method
      count, singular, plural = l_string.split(',').map{ |arg| arg.strip}
      
       "#{count} " + if count == 1 || count == '1'
        singular
      elsif plural
        plural
      elsif Object.const_defined?("Inflector")
        Inflector.pluralize(singular)
      else
        singular + "s"
      end
    end
    
    def reset_l10n_data
      @@languages = []
      @@countries = []
      @@locales = {}
      @@rails_locales = {}
      @@ui_locales = {}
    end

    # Loads ALL the UI localization in memory, I might want to refactor this later on. 
    # (can be hard on the memory if you load 25 languages with 900 entries each)
    def load_localization!
      reset_l10n_data

      # Load the rails localization
      if rails_localization_files
        rails_localization_files.each do |file|
          lang = File.basename(file, '.*')[0,2].downcase.to_sym
          # if a country is defined
          if File.basename(file, '.*')[3,5]
            country = File.basename(file, '.*')[3,5].upcase.to_sym
            @@countries <<  country if ( country != :* && !@@countries.include?(country) )
            if locales.include?("#{lang}-#{country}".to_sym)
              @@locales["#{lang}-#{country}".to_sym].merge(YAML.load_file(file).symbolize_keys)
            else
              @@locales["#{lang}-#{country}".to_sym] = YAML.load_file(file).symbolize_keys
              @@rails_locales[locale_name("#{lang}-#{country}")] = "#{lang}-#{country}".to_sym
            end
            @@languages << lang unless @@languages.include? lang
          else
            @@languages << lang unless @@languages.include? lang 
            @f_locale = "#{lang}-*".to_sym
            @@locales[@f_locale] = @@locales[@f_locale].merge(YAML.load_file(file).symbolize_keys) if locales.include?(@f_locale)
            @@locales[@f_locale] = YAML.load_file(file).symbolize_keys unless locales.include?(@f_locale)
          end
        end
      end
      alias :load_translations! :load_localization!
      alias :load_localizations! :load_localization!
      
      # Load the UI localization
      if ui_localization_files
        ui_localization_files.each do |file| 
          lang = File.basename(file, '.*')[0,2].downcase.to_sym
          if File.basename(file, '.*')[3,5]
            country = File.basename(file, '.*')[3,5].upcase.to_sym
          else
            country = '*'.to_sym
          end
          @@languages << lang unless @@languages.include? lang
          @@countries <<  country if ( country != :* && !@@countries.include?(country) )
          @file_locale = "#{lang}-#{country}".to_sym
          if locales.include?(@file_locale)
            @@locales[@file_locale] = @@locales[@file_locale].merge(YAML.load_file(file).symbolize_keys)
            @@ui_locales[locale_name("#{lang}-#{country}")] = "#{lang}-#{country}".to_sym
          else  
            @@locales[@file_locale] = YAML.load_file(file).symbolize_keys
            @@ui_locales[locale_name("#{lang}-#{country}")] = "#{lang}-#{country}".to_sym
          end
        end
      end
      localize_rails
      # Return the path of the localization files
      return "#{ui_localization_files} | #{rails_localization_files}".to_s
    end

    def locale_name(locale_code)
      locale_code = locale_code.to_sym
      if locales.include?(locale_code)
        @@locales[locale_code][:locale_name] || nil
      end
    end

    protected
    # Return the list of UI files used by Globalite
    def ui_localization_files
      loc_files = Dir[File.join(RAILS_ROOT, 'lang/ui/', '*.{yml,yaml}')]
      unless @@localization_sources.empty?
        @@localization_sources.each do |path|
          loc_files += Dir[File.join(path, '*.{yml,yaml}')]
        end
      end
      loc_files
    end

    # Return a list of the Rails localization files
    def rails_localization_files
      loc_files = Dir[File.join( RAILS_ROOT, '/vendor/plugins/globalite/lang/rails/', '*.{yml,yaml}')]
    end

    # Interpolate a string using the passed arguments
    def interpolate_string(string, args={})
      if args.length > 0
        args.each do |arg|
          string = string.gsub("{#{arg[0].to_s}}", arg[1].to_s)
        end
      end
      string
    end

  end
end