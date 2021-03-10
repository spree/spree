---
title: Authentication and Authorization
section: security
order: 2
---

## Authentication

If you install spree_auth_devise when setting up your app, we use a third party authentication library for Ruby known as [Devise](https://github.com/plataformatec/devise). This library provides a host of useful functionality that is in turn available to Spree, including the following features:

* Authentication
* Strong password encryption (with the ability to specify your own algorithms)
* "Remember Me" cookies
* "Forgot my password" emails
* Token-based/oAuth 2.0 access (for REST API)

### Devise Configuration

<alert kind="note">
A default Spree install comes with the [Spree Auth Devise](https://github.com/spree/spree_auth_devise) gem, which provides authentication for Spree using Devise. This section of the guide covers the default setup. If you're using your own authentication, please consult the manual for that authentication engine.
</alert>

We have configured Devise to handle only what is needed to authenticate with a Spree site. The following details cover the default configurations:

* Passwords are stored in the database encrypted with the salt.
* User authentication is done through the database query.
* User registration is enabled and the user's login is available immediately (no validation emails).
* There is a remember me and password recovery tool built in and enabled through Devise.

These configurations represent a reasonable starting point for a typical e-commerce site. Devise can be configured extensively to allow for a different feature set but that is currently beyond the scope of this document. Developers are encouraged to visit the [Devise wiki](https://github.com/plataformatec/devise/wiki) for more details.

### Authorization

Please refer to [Permissions Customization guide](/developer/customization/permissions.html) for more information.
