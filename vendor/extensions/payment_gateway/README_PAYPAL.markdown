# PayPal Readme

This version includes a migration to add Paypal Website Payments Pro US to Spree. 

To use Paypal Website Payment Pro US, you must first do this:

1. Register with Paypal to get a Paypal Business account. 
2. Sign up for API credentials. You will get a login, password, and signature. The signature is an encrypted string which authenticates your account.
3. go to the Paypal Sandbox and create a Sandbox Seller Account and a Sandbox Buyer account. 
You will use these to test the gateway in the Sandbox environment. The buyer account will 
include a fake credit card number to use in test orders.
5. In the Seller account, sign up for Website Payments Pro. Normally this requires a social security number and a monthly fee but the Sandbox does not.
6. Back in Spree, run the extension migrations to create the Paypal Gateway.
7. Start the server and go to admin/gateways. From the dropdown, choose Paypal Gateway.
8. Paste in your login, password, and signature. Save this gateway. It becomes your selected gateway.
9. Enter a test order and it should complete and be authorized. Go to your Paypal Sandbox Seller account and the transaction should show as Authorized. You must capture the transaction there to complete the transaction.
10. If you get errors authorizing the transaction, use ruby-debug in the checkout_controller to get the full error message from Paypal. Future versions of Spree will log the full message.
11. To use Paypal in production mode, you must have a valid SSL certificate and use https for all transactions. Active Merchant should handle this for you. Test this with real orders and real credit card numbers before launching. You must also sign up for a production Website Payments Pro account with Paypal which requires a check of your business and a contract for monthly fees.
12. See http://www.paypal.com/IntegrationCenter/ic_pro_home.html for documentation.
13. To use Paypal Website Payments Pro on a production site, you are required by Paypal to also use Express Checkout so that customers can checkout directly with their Paypal account. There is one extension which implements most of Paypal Express: see http://ext.spreecommerce.com/extensions/11-spree-paypal-express

