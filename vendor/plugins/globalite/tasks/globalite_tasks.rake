namespace :globalite do
  namespace :localization do

    # Returns a hash with the missing localizations compared to the original locale 
    def missing_localizations(org_base='en-US')
      @langs = {}
      @missing_localizations = {}
      @l_files = Dir[File.join( RAILS_ROOT, '/lang/ui', '*.yml')]
      @l_files.each do |file| 
        if YAML.load_file(file)
          @langs[File.basename(file, '.*')] = YAML.load_file(file).symbolize_keys  
        else
          p "error with the following file: #{file}, the file might be empty"
        end
      end
      @base_keys = @langs[org_base]
      unless @base_keys.blank?
        @langs.each_key do |@lang|
          @base_keys.each_key do |key|
            unless @langs[@lang].include?(key)
              @missing_localizations[@lang] ||= {}
              @missing_localizations[@lang] = @missing_localizations[@lang].merge({key.to_sym => @base_keys[key]})
            end
          end
        end
      else
        p "your #{org_base} file seems empty"
      end
      @missing_localizations
    end

    desc "returns the status of localizations compared to a base locale - rake globalite:localization:status BASE_LOCALE='fr-FR'"
    task :status => :environment do
      @org_base     = ENV['BASE_LOCALE'] || 'en-US'

      @missing_localizations =  missing_localizations(@org_base)
      if @missing_localizations.blank?
        p 'all localization files are up to date'
      else  
        @missing_localizations.each_key do |lang|
          p "#{@missing_localizations[lang].length} translations missing in #{lang}" if @missing_localizations[lang].length > 0
        end  
      end  
    end

  end
end