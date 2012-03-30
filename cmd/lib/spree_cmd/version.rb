module SpreeCmd
  class Version < Thor::Group
    include Thor::Actions

		desc 'display spree_cmd version'
		
		def cmd_version
			puts Gem.loaded_specs['spree_cmd'].version
		end

  end
end
