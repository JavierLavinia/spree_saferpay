SpreeSaferpay
============

Basic support for the Saferpay Virtual TPV,  Spree 1.2.X compatible

Based on https://github.com/picazoH/spree_sermepa Library by @picazoH


Install
=======

Add the following lines to your application's Gemfile.

gem "spree_saferpay", github: 'simplelogica/spree_saferpay'
gem 'saferpay', github: "simplelogica/saferpay-gem", branch: 'httparty-0.8.3'

Configuring
===========
Add a new Payment Method, using: Spree::BillingIntegration::SaferpayPayment as the Prodivder

Click Create, and enter your Saferpay account details.

Save and enjoy!
