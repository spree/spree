require 'yaml'
require 'pry'

hash = YAML.load_file("core/config/locales/en.yml")
hash["en"]["spree"].each do |k,v|
  if String === v
  	# Check for translations used in controllers, models, views, mailers, helpers and lib
    command = %Q{ack "t\\(:#{k}" */app/**/* */lib/**}
    # Check for possible preferences matching translations
    # This is because preference_field within backend uses it like Spree.t(:<preference_key>)
    symbol_command = %Q{ack ":#{k}" */app/**/* */lib/**}
    `#{command}`
    command_status = $?.exitstatus
    `#{symbol_command}`
    symbol_command_status = $?.exitstatus
    if command_status == 1 && symbol_command_status == 1
      puts "Couldn't find #{k} translation"
    end
  else
  	# TODO: Account for nested keys.
  	# I didn't do this because there's not that many nested keys in en.yml
  	# and it's easy to verify with my eyes.
  end
end
