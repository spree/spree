// --- Dependencies
import * as React from 'react'
import { graphql } from 'gatsby'
import Img from 'gatsby-image'

// --- Components
import Layout from 'components/Layout'
import Section from 'components/Section'


/**
 * Component
 */

 export default ({ data }) => (
  <Layout
    title="Guides"
    description="Spree Commerce API, documentation, guides & tutorials"
  >
    <div className="mw8 center mt4 pa2-ns">
      <Img
        fluid={data.file.childImageSharp.fluid}
        alt="Spree Commerce Documentation"
        className="br4 ba b--light-silver"
      />
    </div>

    <div className="mw8 center mt4 pa2-ns mb3">
      <h1 className="lh-copy f3 tc ph4 pv2">
        <a href="https://spreecommerce.org" className="spree-blue fw6">
          Spree Commerce
        </a> is a complete, modular, API-driven open source e-commerce solution built with Ruby on Rails
      </h1>

      <p class="tc mb3">
        <strong>First time?</strong> We recommend you read the&nbsp;
        <a href="/developer/getting_started/installation.html">Getting Started</a> tutorial
      </p>

      <div className="mw8 center">
        <div className="flex flex-column flex-wrap flex-row-ns mv4 w-100">
          <Section path="/api/" title="API Reference" className="w-50-ns">
            <p>
              The REST API is designed to give developers a convenient way to
              access data contained within Spree. With a standard read/write
              interface to store data, it is now very simple to write third party
              applications (JavaScript/Mobile/other technologies) that can talk to
              your Spree store.
            </p>
            <ul className="list ph0 mb0">
              <li className="dib mr2"><a href="/api/v1/summary.html">REST API v1</a></li>
              <li className="dib mr2"><a href="https://api.spreecommerce.org/docs/api-v2/api/docs/v2/storefront/index.yaml">REST API v2</a></li>
            </ul>
          </Section>

          <Section path="/extensions/" title="Extensions" className="w-50-ns">
            <p>
              Extensions provide additional features and integrations for your Spree store.
              Content Management, Internationalization, Order Management, Marketing, Marketplace, Payments providers, Shipping, Tax Calculation and more!
            </p>
          </Section>

          <Section
            path="/developer"
            title="Developer Guides"
            className="w-50-ns"
          >
            <p>
              This part of Spree’s documentation covers the technical aspects of
              Spree. If you are working with Rails and are building a Spree store,
              this is the documentation for you.
            </p>
            <ul className="list ph0 mb0">
              <li className="dib mr2"><a href="/developer/customization/storefront.html">Customization</a></li>
              <li className="dib mr2"><a href="/developer/internals">Internals</a></li>
              <li className="dib mr2"><a href="/developer/deployment">Deployment</a></li>
              <li className="dib mr2"><a href="/developer/security">Security</a></li>
              <li className="dib mr2"><a href="/developer/upgrades">Upgrades</a></li>
            </ul>

          </Section>

          <Section path="/user" title="User Guides" className="w-50-ns">
            This documentation is intended for business owners and site
            administrators of Spree e-commerce sites. Everything you need to
            know to configure and manage your Spree store can be found here.
          </Section>

          <Section
            path="/release_notes"
            title="Release Notes"
            className="w-50-ns"
          >
            Each major new release of Spree has an accompanying set of release
            notes. The purpose of these notes is to provide a high level
            overview of what has changed since the previous version of Spree.
          </Section>
        </div>

        <p class="tc">
          Didn't found what you're looking for?
          <br />
          Go ahead and <a href="http://slack.spreecommerce.org/" target="_blank" rel="nofollow">join our Slack</a> or <a href="https://spreecommerce.org/contact/">contact us</a> directly.
        </p>

      </div>
    </div>
  </Layout>
)

export const query = graphql`
  query {
    file(relativePath: { eq: "features/spree_header_978@2x.png" }) {
      childImageSharp {
        # Specify the image processing specifications right in the query.
        # Makes it trivial to update as your page's design changes.
        fluid(quality: 80) {
          ...GatsbyImageSharpFluid
        }
      }
    }
  }
`
