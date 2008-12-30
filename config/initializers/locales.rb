LOCALES_DIRECTORY = "#{RAILS_ROOT}/config/locales/" 
AVAILABLE_LOCALES =
Dir.new(LOCALES_DIRECTORY).entries.collect do |x|
  x =~ /\.yml/ ? x.sub(/\.yml/,"") : nil
end.compact.each_with_object({}) do |str, hsh|
  hsh[str] = YAML.load_file(LOCALES_DIRECTORY + str + ".yml")[str]["this_file_language"]
end.freeze
