# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  before_filter :instantiate_controller_and_action_names
  around_filter :set_locale

  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_spree_session_id'

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery #:secret => '55a66755bef2c41d411bd5486c001b16'

  include AuthenticatedSystem
  include RoleRequirementSystem
  include EasyRoleRequirementSystem
  
  private 
  
  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end

  # Set the locale from the parameters, the session, or the navigator
  # If none of these works, the Globalite default locale is set (en-*)
  def set_locale
    # Get the current path and request method (useful in the layout for changing the language)
    @current_path = request.env['PATH_INFO']
    @request_method = request.env['REQUEST_METHOD']

    # Try to get the locale from the parameters, from the session, and then from the navigator
    if params[:user_locale]
      # Store the locale in the session
      Locale.code = params[:user_locale][:code] #get_matching_ui_locale(params[:user_locale][:code]) #|| session[:locale] || get_valid_lang_from_accept_header || Globalite.default_language
      session[:locale] = Locale.code
    elsif session[:locale]
      Locale.code = session[:locale]
    else
      Locale.code = local_case(get_valid_lang_from_accept_header)
    end
    
    logger.debug "[globalite] Locale set to #{Locale.code}"
    # render the page
    yield

    # reset the locale to its default value
    Locale.reset!
  end

  # Get a sorted array of the navigator languages
  def get_sorted_langs_from_accept_header
    accept_langs = (request.env['HTTP_ACCEPT_LANGUAGE'] || "en-us,en;q=0.5").split(/,/) rescue nil
    return nil unless accept_langs

    # Extract langs and sort by weight
    # Example HTTP_ACCEPT_LANGUAGE: "en-au,en-gb;q=0.8,en;q=0.5,ja;q=0.3"
    wl = {}
    accept_langs.each {|accept_lang|
      if (accept_lang + ';q=1') =~ /^(.+?);q=([^;]+).*/
        wl[($2.to_f rescue -1.0)]= $1
      end
    }
    logger.debug "[globalite] client accepted locales: #{wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }.to_sentence}"
    sorted_langs = wl.sort{|a,b| b[0] <=> a[0] }.map{|a| a[1] }
  end

  # Returns a valid language that best suits the HTTP_ACCEPT_LANGUAGE request header.
  # If no valid language can be deduced, then <tt>nil</tt> is returned.
  def get_valid_lang_from_accept_header
    # Get the sorted navigator languages and find the first one that matches our available languages
    get_sorted_langs_from_accept_header.detect{|l| get_matching_ui_locale(l) }
  end

  # Returns the UI locale that best matches with the parameter
  # or nil if not found
  def get_matching_ui_locale(locale)
    lang = locale[0,2].downcase
    
    # Check with exact matching
    if Globalite.ui_locales.values.include?(local_case(locale))
      local_case(locale)
    end

    # Check on the language only
    Globalite.ui_locales.values.each do |value|
      value.to_s =~ /#{lang}-*/ ? value : nil
    end
  end
  def local_case(l)
    if l[3,5]
      "#{l[0,2]}-#{l[3,5].upcase}".to_sym
    else
      "#{l[0,2]}-*".to_sym
    end
  end

  
end
