namespace :spree do
  namespace :dependencies do
    desc 'List all Spree dependencies with their current values'
    task list: :environment do
      print_dependencies('CORE', Spree::Dependencies)
      print_dependencies('API', Spree::Api::Dependencies) if defined?(Spree::Api::Dependencies)
    end

    desc 'Show only overridden dependencies'
    task overrides: :environment do
      core_overrides = Spree::Dependencies.current_values.select { |d| d[:overridden] }
      api_overrides = if defined?(Spree::Api::Dependencies)
                        Spree::Api::Dependencies.current_values.select { |d| d[:overridden] }
                      else
                        []
                      end

      if core_overrides.empty? && api_overrides.empty?
        puts 'No dependencies have been overridden.'
      else
        print_overrides('Core', core_overrides) if core_overrides.any?
        print_overrides('API', api_overrides) if api_overrides.any?
      end
    end

    desc 'Validate all dependencies resolve to valid classes'
    task validate: :environment do
      errors = validate_dependencies('Core', Spree::Dependencies)
      errors += validate_dependencies('API', Spree::Api::Dependencies) if defined?(Spree::Api::Dependencies)

      puts "\n"
      if errors.any?
        puts "\n\e[31m#{errors.size} invalid dependencies:\e[0m"
        errors.each { |err| puts "  [#{err[:source]}] #{err[:name]}: #{err[:error]}" }
        exit 1
      else
        puts "\e[32mAll dependencies valid\e[0m"
      end
    end

    def print_dependencies(name, deps)
      puts "\n[#{name}]"

      # Calculate max width for alignment
      max_name_width = deps.class::INJECTION_POINTS.map(&:length).max

      deps.current_values.each do |dep|
        status = dep[:overridden] ? ' [OVERRIDDEN]' : ''
        puts "#{dep[:name].to_s.ljust(max_name_width)}  #{dep[:current]}#{status}"
      end
    end

    def print_overrides(name, overrides)
      puts "\n[#{name} OVERRIDES]"

      max_name_width = overrides.map { |d| d[:name].length }.max

      overrides.each do |dep|
        source = dep[:override_info] ? " (#{dep[:override_info][:source]})" : ''
        puts "#{dep[:name].to_s.ljust(max_name_width)}  #{dep[:default]} -> #{dep[:current]}#{source}"
      end
    end

    def validate_dependencies(name, deps)
      errors = []
      deps.class::INJECTION_POINTS.each do |point|
        deps.send("#{point}_class")
        print "\e[32m.\e[0m"
      rescue NameError => e
        errors << { source: name, name: point, error: e.message }
        print "\e[31mF\e[0m"
      end
      errors
    end
  end
end
