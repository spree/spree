require 'fileutils'

# Install all the needed support files (CSS and JavaScript)

js_dir = File.dirname(__FILE__) + '/../../../public/javascripts/'
datepicker_js = js_dir + 'datepicker.js'
lang_dir = js_dir + 'lang'
datepicker_css = File.dirname(__FILE__) + '/../../../public/stylesheets/datepicker.css'
images_dir = File.dirname(__FILE__) + '/../../../public/images/datepicker'

FileUtils.cp File.dirname(__FILE__) + '/public/javascripts/datepicker.js', datepicker_js unless File.exists?(datepicker_js)
FileUtils.cp_r File.dirname(__FILE__) + '/public/javascripts/lang/', lang_dir unless File.exists?(lang_dir)
FileUtils.cp File.dirname(__FILE__) + '/public/stylesheets/datepicker.css', datepicker_css unless File.exists?(datepicker_css)
FileUtils.cp_r File.dirname(__FILE__) + '/public/images/', images_dir unless File.exists?(images_dir)
