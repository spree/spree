import * as React from 'react'

import Layout from '../../../components/Layout'
import openApiNav from '../../../utils/openApiNav'
import ExternalLink from '../../../components/ExternalLink'

const IndexPage = () => (
  <Layout activeSection="API V2" nav={openApiNav}>
    <h1>REST API v2</h1>
    <p>
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
    </p>

    <strong>REST API v2</strong> consists of 2 parts:
    <ul>
      <li>
        <a href="/api/v2/storefront">Storefront</a>
        <br />
        All necessary API endpoints to build a custom Storefront in
        any technology (JavaScript/Mobile)
      </li>
      <li>
        Platform (Work in Progress)
        <br />
        API endpoints for any admin level privileges actions.
        Designed for connecting to 3rd party systems like WMS, retail Points of Sale, etc
      </li>
    </ul>

    REST API v2 supports those JSON API features:
    <ul>
      <li>
        Returning&nbsp;
        <ExternalLink url="https://jsonapi.org/format/#document-resource-object-relationships">
          Relationships
        </ExternalLink>
        &nbsp;of objects in the response JSON
      </li>
      <li>
        Declaring and fetching Related Resources
      </li>
      <li>
        Sparse Fieldsets to fetch only selected attributes of objects and their relationships
      </li>
    </ul>
  </Layout>
)

export default IndexPage
