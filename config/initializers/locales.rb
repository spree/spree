LOCALES_DIRECTORY = "#{SPREE_ROOT}/config/locales/" 
AVAILABLE_LOCALES =
Dir.new(LOCALES_DIRECTORY).entries.collect do |x|
  x =~ /\.yml/ ? x.sub(/\.yml/,"") : nil
end.compact.each_with_object({}) do |str, hsh|
  locale_file = YAML.load_file(LOCALES_DIRECTORY + str + ".yml")
  hsh[str] = locale_file[str]["this_file_language"] if locale_file.has_key? str
end.freeze