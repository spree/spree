def page_has_links(table)
  table.hashes.each do |h|
    selector = h[:within][1..-1]
    #b = page.all(:xpath, "//div[@id='admin-menu']//a")
    #puts b.each {|r| puts r.native }
    page.should have_xpath( "//div[@id='#{selector}']//a[@href='#{h[:url]}']", :text => h[:text] )
  end
end

# Usage:
#
# Then page should have following links:
#  | url                                      | text          | within      |
#  | http://github.com/railsdog/spree         | admin_data    | #footer     |
#  | http://github.com/railsdog/spree/issues  | Report Bug    | #footer     |
#  | http://github.com/railsdog/spree/wiki    | Documentation | #footer     |
#  | /admin                                   | Admin         | #admin-menu |
Then /^page should have following links?:$/ do |table|
  page_has_links(table)
end
