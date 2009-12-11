if defined? Less::Command   
  require File.join(File.dirname(__FILE__), '..', 'lib', 'more')

  config.after_initialize {
    Less::More.clean
    Less::More.parse if Less::More.page_cache?
  }  
end