## Spree 2.4.0 (unreleased) ##

*   Rename `spree/frontend/app/views/spree/shared/_google_analytics.html.erb`
    file to `spree/frontend/app/views/spree/shared/_google_analytics.js.erb'.
    See PR [#5634](https://github.com/spree/spree/pull/5634) for the changes to GA.
    For upgrading: please move the google analytics partial from the bottom to the
    top of the page and we recommend using this erb (note the if statement):
    ```erb
    <%= render 'spree/shared/google_analytics' if Spree::Tracker.current %>
    ```

    Ben A. Morgan
