require File.dirname(__FILE__) + '/../spec_helper'

describe LocaleController do

  #Delete these examples and add some real ones
  it "should use LocaleController" do
    controller.should be_an_instance_of(LocaleController)
  end

  describe 'route generation' do
    it 'should generate correct routes' do
      # set_locale_path(:locale => 'es-ES').should == "/locale/set?locale=es-ES"
      route_for(:controller => 'locale', :action => 'set', :locale => 'en-US').should == "/locale/set?locale=en-US"
    end
  end

  # describe 'route recognition' do
  #   it 'should generate params {:controller => "locale", :action => "set", :locale => "en-US"} from GET /locale/set?locale=en-US' do
  #     params_from(:get, '/locale/set?locale=en-US').should == {:controller => 'locale', :action => 'set', :locale => 'en-US'}
  #   end
  # end
end
