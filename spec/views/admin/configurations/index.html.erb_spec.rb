require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

include PreferenceFactory

describe "/admin/configurations" do


  before(:each) do
    assigns[:extension_links] = []
    render 'admin/configurations/index'
  end
  
  it "should display a Mail Server Settings link" do
    response.should have_tag('a[href=?]', admin_mail_settings_path)
  end

  it "should display a Tax Categories link" do
    response.should have_tag('a[href=?]', admin_tax_categories_path)
  end

  it "should display a Zones link" do
    response.should have_tag('a[href=?]', admin_zones_path)
  end

  it "should display a States link" do
    response.should have_tag('a[href=?]', admin_country_states_path(214))
  end

  it "should display a Gateway link" do
    response.should have_tag('a[href=?]', admin_gateways_path)
  end

  it "should display an Inventory Settings link" do
    response.should have_tag('a[href=?]', admin_inventory_settings_path)
  end

end
