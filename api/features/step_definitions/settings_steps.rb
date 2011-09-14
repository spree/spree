Given /^I am a valid API user but not admin$/ do
  @user = Factory(:user)
  authorize @user.authentication_token, "X"
end

Then /^I set "([^"]*)" and PUT request to "([^"]*)"$/ do |data,path|
  put path,'{"setting":{"select_taxons_from_tree":true,"orders_per_page":100}}'
end

When /^I send xml and PUT request to "([^"]*)"$/ do |path|
  data= <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<setting>
  <orders-per-page type="integer">777</orders-per-page>
  <create-inventory-units type="boolean">true</create-inventory-units>
  <show-zero-stock-products type="boolean">true</show-zero-stock-products>
  <select-taxons-from-tree type="boolean">false</select-taxons-from-tree>
  <default-seo-title></default-seo-title>
  <shipping-instructions type="boolean">false</shipping-instructions>
  <address-requires-state type="boolean">true</address-requires-state>
  <allow-ssl-in-production type="boolean">true</allow-ssl-in-production>
  <site-url>demo.spreecommerce.com</site-url>
  <admin-interface-logo>admin/bg/spree_50.png</admin-interface-logo>
  <allow-backorders type="boolean">true</allow-backorders>
  <allow-locale-switching type="boolean">true</allow-locale-switching>
  <default-meta-description>Spree demo site</default-meta-description>
  <admin-pgroup-preview-size type="integer">10</admin-pgroup-preview-size>
  <logo>admin/bg/spree_50.png</logo>
  <alternative-billing-phone type="boolean">false</alternative-billing-phone>
  <use-content-controller type="boolean">true</use-content-controller>
  <show-price-inc-vat type="boolean">false</show-price-inc-vat>
  <allow-guest-checkout type="boolean">true</allow-guest-checkout>
  <products-per-page type="integer">10</products-per-page>
  <show-descendents type="boolean">true</show-descendents>
  <shipment-inc-vat type="boolean">false</shipment-inc-vat>
  <auto-capture type="boolean">false</auto-capture>
  <alternative-shipping-phone type="boolean">false</alternative-shipping-phone>
  <track-inventory-levels type="boolean">true</track-inventory-levels>
  <default-meta-keywords>spree, demo</default-meta-keywords>
  <default-locale>en</default-locale>
  <default-country-id type="integer">214</default-country-id>
  <allow-ssl-in-development-and-test type="boolean">false</allow-ssl-in-development-and-test>
  <always-put-site-name-in-title type="boolean">true</always-put-site-name-in-title>
  <stylesheets>reset,screen</stylesheets>
  <site-name>Spree Demo Site</site-name>
  <admin-products-per-page type="integer">10</admin-products-per-page>
  <allow-backorder-shipping type="boolean">false</allow-backorder-shipping>
  <allow-checkout-on-gateway-error type="boolean">false</allow-checkout-on-gateway-error>
  <cache-static-content type="boolean">true</cache-static-content>
  <checkout-zone nil="true"></checkout-zone>
  <max-level-in-taxons-menu type="integer">1</max-level-in-taxons-menu>
  <show-only-complete-orders-by-default type="boolean">true</show-only-complete-orders-by-default>
  </setting>
EOF
  put path,data
end

Then /^response "([^"]*)" should be "([^"]*)"$/ do |set,curr_data|
  page = JSON.load(last_response.body)
  page['setting'][set].to_s.should == curr_data
end

Then /^response xml "([^"]*)" should be "([^"]*)"$/ do |set,curr_data|
  page = Nokogiri::XML(last_response.body)
  page.xpath('setting').xpath(set).text.should == curr_data
end
