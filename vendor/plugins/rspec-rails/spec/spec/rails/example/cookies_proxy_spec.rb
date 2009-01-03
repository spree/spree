require File.dirname(__FILE__) + '/../../../spec_helper'

class CookiesProxyExamplesController < ActionController::Base
  def index
    cookies[:key] = cookies[:key]
    render :text => ""
  end
end

module Spec
  module Rails
    module Example
      describe CookiesProxy, :type => :controller do
        controller_name :cookies_proxy_examples
      
        describe "with a String key" do
        
          it "should accept a String value" do
            cookies = CookiesProxy.new(self)
            cookies['key'] = 'value'
            get :index
            if ::Rails::VERSION::STRING >= "2.3"
              cookies['key'].should == 'value'
            else
              cookies['key'].should == ['value']
            end
          end
          
          if ::Rails::VERSION::STRING >= "2.0.0"
            it "should accept a Hash value" do
              cookies = CookiesProxy.new(self)
              cookies['key'] = { :value => 'value', :expires => expiration = 1.hour.from_now, :path => path = '/path' }
              get :index
              if ::Rails::VERSION::STRING >= "2.3"
                cookies['key'].should == 'value'
              else
                cookies['key'].should == ['value']
                cookies['key'].value.should == ['value']
                cookies['key'].expires.should == expiration
                cookies['key'].path.should == path
              end
            end
          end
            
        end
      
        describe "with a Symbol key" do
        
          it "should accept a String value" do
            example_cookies = CookiesProxy.new(self)
            example_cookies[:key] = 'value'
            get :index
            if ::Rails::VERSION::STRING >= "2.3"
              example_cookies[:key].should == 'value'
            else
              example_cookies[:key].should == ['value']
            end
          end

          if ::Rails::VERSION::STRING >= "2.0.0"
            it "should accept a Hash value" do
              example_cookies = CookiesProxy.new(self)
              example_cookies[:key] = { :value => 'value', :expires => expiration = 1.hour.from_now, :path => path = '/path' }
              get :index
              if ::Rails::VERSION::STRING >= "2.3"
                example_cookies[:key].should == 'value'
              else
                example_cookies[:key].should == ['value']
                example_cookies[:key].value.should == ['value']
                example_cookies[:key].expires.should == expiration
                example_cookies[:key].path.should == path
              end
            end
          end

        end
    
        describe "#delete" do
          it "should delete from the response cookies" do
            example_cookies = CookiesProxy.new(self)
            response_cookies = mock('cookies')
            response.should_receive(:cookies).and_return(response_cookies)
            response_cookies.should_receive(:delete).with('key')
            example_cookies.delete :key
          end
        end
      end
    
    end
  end
end
