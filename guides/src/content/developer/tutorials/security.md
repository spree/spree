---
title: Security
section: advanced
---

## Overview

Proper application design, intelligent programming, and secure infrastructure are all essential in creating a secure e-commerce store using any software (Spree included). The Spree team has done its best to provide you with the tools to create a secure and profitable web presence, but it is up to you to take these tools and put them in good practice. We highly recommend reading and understanding the [Rails Security Guide](http://guides.rubyonrails.org/security.html).

## Reporting Security Issues

Please do not announce potential security vulnerabilities in public. We have a [dedicated email address](mailto:security@spreecommerce.org). We will work quickly to determine the severity of the issue and provide a fix for the appropriate versions. We will credit you with the discovery of this patch by naming you in a blog post.

If you would like to provide a patch yourself for the security issue **do not open a pull request for it**. Instead, create a commit on your fork of Spree and run this command:

```bash
git format-patch HEAD~1..HEAD --stdout > patch.txt
```

This command will generate a file called `patch.txt` with your changes. Please email a description of the patch along with the patch itself to our [dedicated email address](mailto:hi@spreecommerce.org).

## Authentication

If you install spree_auth_devise when setting up your app, we use a third party authentication library for Ruby known as [Devise](https://github.com/plataformatec/devise). This library provides a host of useful functionality that is in turn available to Spree, including the following features:

* Authentication
* Strong password encryption (with the ability to specify your own algorithms)
* "Remember Me" cookies
* "Forgot my password" emails
* Token-based/oAuth 2.0 access (for REST API)

### Devise Configuration

<alert kind="note">
A default Spree install comes with the [spree_auth_devise](https://github.com/spree/spree_auth_devise) gem, which provides authentication for Spree using Devise. This section of the guide covers the default setup. If you're using your own authentication, please consult the manual for that authentication engine.
</alert>

We have configured Devise to handle only what is needed to authenticate with a Spree site. The following details cover the default configurations:

* Passwords are stored in the database encrypted with the salt.
* User authentication is done through the database query.
* User registration is enabled and the user's login is available immediately (no validation emails).
* There is a remember me and password recovery tool built in and enabled through Devise.

These configurations represent a reasonable starting point for a typical e-commerce site. Devise can be configured extensively to allow for a different feature set but that is currently beyond the scope of this document. Developers are encouraged to visit the [Devise wiki](https://github.com/plataformatec/devise/wiki) for more details.

### REST API v1

The REST API behaves slightly differently than a standard user. First, an admin has to create the access key before any user can query the REST API. This includes generating the key for the admin him/herself. This is not the case if `Spree::Api::Config[:requires_authentication]` is set to `false`.

In cases where `Spree::Api::Config[:requires_authentication]` is set to `false`, read-only requests in the API will be possible for all users. For actions that modify data within Spree, a user will need to have an API key and then their user record would need to have permission to perform those actions.

It is up to you to communicate that key. As an added measure, this authentication has to occur on every request made through the REST API as no session or cookies are created or stored for the REST API.

### Authorization

Please refer to [Permissions Customization guide](/developer/customization/permissions.html) for more information.

## Credit Card Data

### PCI Compliance

All store owners wishing to process credit card transactions should be familiar with [PCI Compliance](http://en.wikipedia.org/wiki/Pci_compliance). [Spree Gateway Stripe itnegration](https://github.com/spree/spree_gateway) and [Spree Braintree vzero](https://github.com/spree-contrib/spree_braintree_vzero) are PCI-compliant.

### Transmit Exactly Once

Spree uses extreme caution in its handling of credit cards. In production mode, credit card data is transmitted to Spree via SSL. The data is immediately relayed to your chosen payment gateway and then discarded. The credit card data is never stored in the database (not even temporarily) and it exists in memory on the server for only a fraction of a second before it is discarded.

Spree does store the last four digits of the credit card and the expiration month and date. You could easily customize Spree further if you wanted and opt out of storing even that little bit of information.
