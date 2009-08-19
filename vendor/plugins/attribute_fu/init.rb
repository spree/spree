# Commented out (by Jorge Calas) as we initialize attribute_fu in config/initializers/spree.rb
#
#ActiveRecord::Base.class_eval { include AttributeFu::Associations }
#ActionView::Helpers::FormBuilder.class_eval { include AttributeFu::AssociatedFormHelper }

unless defined?('RAILS_ROOT')
  # copy the required javascript file (if it hasn't been copied already)
  target_dir = "#{RAILS_ROOT}/public/javascripts"
  FileUtils.mkdir_p(target_dir) unless File.directory?(target_dir)
  FileUtils.cp(File.join(File.dirname(__FILE__), 'javascripts/jquery.template.js'), "#{RAILS_ROOT}/public/javascripts") unless File.exists?("#{RAILS_ROOT}/public/javascripts/jquery.template.js")
end

