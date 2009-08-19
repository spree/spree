require 'fileutils'

js_dir = File.dirname(__FILE__) + '/../../../public/javascripts/'
datepicker_js = js_dir + 'datepicker.js'
lang_dir = js_dir + 'lang'
datepicker_css = File.dirname(__FILE__) + '/../../../public/stylesheets/datepicker.css'
images_dir = File.dirname(__FILE__) + '/../../../public/images/datepicker'

FileUtils.rm datepicker_js
FileUtils.rm_r lang_dir
FileUtils.rm datepicker_css
FileUtils.rm_r images_dir
