require 'spec_helper'

describe "Template rendering" do

  context "with application layout present" do

    before do
      @app_layout = Rails.root.join('app/views/layouts', 'application.html.erb')
      File.open(@app_layout, 'w') do |app_layout|
        app_layout.puts "<html>I am the application layout</html>"
      end
    end

    it "should render application layout" do
      visit spree.root_path
      page.should_not have_content('Spree Demo Site')
      page.should have_content('I am the application layout')
    end

    after do
      FileUtils.rm(@app_layout)
    end

  end

  context "with application layout absent" do

    it "should render default layout" do
      visit spree.root_path
      page.should_not have_content('I am the application layout')
      page.should have_content('Spree Demo Site')
    end

  end

end
