// --- Dependencies
import * as React from 'react'
import { Link } from 'gatsby'

// --- Components
import Layout from '../../../components/Layout'
import openApiNav from '../../../utils/openApiNav'
import ExternalLink from '../../../components/ExternalLink'
import H1 from '../../../components/base/H1'
import H2 from '../../../components/base/H2'
import H3 from '../../../components/base/H3'
import P from '../../../components/base/P'

/**
 * Component
 */

const IndexPage = () => (
  <Layout activeSection="API V2" nav={openApiNav} activeRootSection="api">
    <H1>REST API v2</H1>
    <P>
      Modern lightweight REST API based on &nbsp;
      <ExternalLink url="https://jsonapi.org/format/">
        JSON API schema
      </ExternalLink>
      &nbsp; built on top of Netflix &nbsp;
      <ExternalLink url="https://github.com/Netflix/fast_jsonapi">
        fast_json_api
      </ExternalLink>
      &nbsp; gem and oAuth authentication via &nbsp;
      <ExternalLink url="https://github.com/doorkeeper-gem/doorkeeper">
        doorkeeper
      </ExternalLink>
      &nbsp;gem.
    </P>
    <H2>REST API v2 components</H2>
    <h3>
      <Link to="/api/v2/storefront">Storefront</Link>
    </h3>
    <P>
      All necessary API endpoints to build a custom Storefront in any technology
      (JavaScript/Mobile).
      <br />
      Resources such as Products and Taxons are made publicly accessible by
      default.
      <br />
      Simplified{' '}
      <Link to="/api/v2/storefront#section/Authentication">authentication</Link>
      &nbsp;to support both signed in users and guest checkouts.
    </P>
    <ExternalLink url="https://github.com/spree/spree-storefront-api-v2-js-sdk">
      Download JavaScript/TypeScript SDK
    </ExternalLink>
    <H3>
      Platform <em>(Work in Progress)</em>
    </H3>
    <P>
      API endpoints for any admin level privileges actions. Designed to connect
      3rd party systems like WMS, retail Points of Sale, etc.
      <br />
      We plan on including Platform API in one of the Spree 4.x releases.
    </P>
    <H2>JSON API features supported</H2>
    All REST API v2 endpoints support these JSON API features:
    <ul>
      <li>
        <ExternalLink url="https://jsonapi.org/format/#document-resource-object-relationships">
          Relationships
        </ExternalLink>
        <br />
        Returns a set of related objects IDs the same response JSON
      </li>
      <li>
        <ExternalLink url="https://jsonapi.org/format/#fetching-includes">
          Fetching Related Resources
        </ExternalLink>
        <br />
        In one API request you can fetch multiple resources related to the main
        object, eg. Product with Variants and Images of those Variants. Thanks
        to this you don't need to make multiple requests to the API greatly
        simplifying your frontend code and also creating a smoother experience
        for your users.
      </li>
      <li>
        <ExternalLink url="https://jsonapi.org/format/#fetching-sparse-fieldsets">
          Sparse Fieldsets
        </ExternalLink>
        <br />
        Fetch only selected attributes of objects and their relationships.
        Thanks to this JSON response will be lean and exactly how you require it
        without any overload and overfetching.
      </li>
    </ul>
  </Layout>
)

export default IndexPage
