require 'spree/extension'

all_locale_paths = Spree::ExtensionLoader.load_extension_roots.dup << SPREE_ROOT

AVAILABLE_LOCALES = {}

all_locale_paths.each do |path|
	path = File.join(path, 'config', 'locales')

	if File.exists? path
		locales = Dir.new(path).entries.collect do |x|
		  x =~ /^[^\.].+\.yml$/ ? x.sub(/\.yml/,"") : nil
		end.compact.each_with_object({}) do |str, hsh|
		  locale_file = YAML.load_file(path + "/" + str + ".yml")
		  hsh[str] = locale_file[str]["this_file_language"] if locale_file.has_key? str
		end.freeze
	
		AVAILABLE_LOCALES.merge! locales
	end
end
