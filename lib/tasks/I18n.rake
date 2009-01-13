# http://www.99translations.com/p/52/files/Core/en-US
require 'net/http'

namespace :i18n do
  desc "Update locale yaml files from 99Translations.com"
  task :update => :environment do

    project_url = 'http://www.99translations.com/p/52/files'
    
    files = [{:name => "Core", :path => "config/locales/"}, {:name => "Shipping", :path => "vendor/extensions/shipping/config/locales/"}, {:name => "Tax", :path => "vendor/extensions/tax_calculator/config/locales/"}]
    locales = %w(en-US en-GB de it es pl pt-BR)
    
    files.each do |file|
      
      locales.each do |locale|
        locale_url = [project_url, file[:name], locale].join("/")
        
        puts "Getting: #{locale_url}"
        
        url = URI.parse(locale_url)
        req = Net::HTTP::Get.new(url.path)
        res = Net::HTTP.start(url.host, url.port) {|http|
          http.request(req)
        }
        
        if res.body.include? "#{locale}:"     
          locale_file = file[:path] + locale + ".yml"
          puts "Writing to file: #{locale_file}"
        
          File.open(locale_file, 'w') do |yaml_file|  
            yaml_file.puts res.body
          end
        else
          puts "Skipped: Failed retreive valid locale file from: #{locale_url}"
        end
      end
    end
    
  end
  
end
  