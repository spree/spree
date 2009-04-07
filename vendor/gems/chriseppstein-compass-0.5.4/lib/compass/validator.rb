require File.join(File.dirname(__FILE__), 'core_ext')
require File.join(File.dirname(__FILE__), 'constants')

module Compass
  # Validates generated CSS against the W3 using Java
  class Validator
    VALIDATOR_FILE = File.join(File.dirname(__FILE__), 'validate', 'css-validator.jar')
    attr_reader :error_count
    
    def initialize
      @error_count = 0
    end

    # Validates all three CSS files
    def validate
      java_path = `which java`.rstrip
      raise "You do not have a Java installed, but it is required." if java_path.blank?
    
      output_header
    
      Dir.new(Compass::Constants::BLUEPRINT_ROOT_PATH).each do |file_name|
        puts "#{file_name}"
        if file_name =~ /\.css$/
          css_file = File.join(Compass::Constants::BLUEPRINT_ROOT_PATH, file_name)
          @error_count += 1 if !validate_css_file(java_path, css_file)
        end
      end
    
      output_footer
    end
    
    private
    def validate_css_file(java_path, css_file)
      puts "\n\n  Testing #{css_file}"
      puts "  Output ============================================================\n\n"
      system("#{java_path} -jar '#{VALIDATOR_FILE}' -e '#{css_file}'")
    end
    
    def output_header
      puts "\n\n"
      puts "  ************************************************************"
      puts "  **"
      puts "  **   Compass CSS Validator"
      puts "  **   Validates output CSS files"
      puts "  **"
      puts "  ************************************************************"
    end

    def output_footer
      puts "\n\n"
      puts "  ************************************************************"
      puts "  **"
      puts "  **   Done!"
      puts "  **   Your CSS files are#{" not" if error_count > 0} valid.#{"  You had #{error_count} error(s) within your files" if error_count > 0}"
      puts "  **"
      puts "  ************************************************************"
    end
  end
end