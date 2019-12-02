// --- Dependencies
import * as React from 'react'

// --- Components
import Layout from 'components/Layout'
import Section from 'components/Section'

/**
 * Component
 */

const IndexPage = () => (
  <Layout
    pathname="/"
    title="Home"
    description="Spree Commerce API, documentation, guides & tutorials"
  >
    <div className="center mw9 ph4 mt5">
      <p className="lh-copy f3 tc mw7 center mb5">
        <a href="https://spreecommerce.org" className="spree-blue fw6">
          Spree Commerce
        </a>
        &nbsp;is a complete, modular, API-driven open source e-commerce solution
        &nbsp;built with Ruby on Rails
      </p>

      <div className="mw8 center">
        <div className="flex flex-column flex-wrap flex-row-ns mv4 w-100">
          <Section path="/api/overview" title="API Guides" className="w-50-ns">
            The REST API is designed to give developers a convenient way to
            access data contained within Spree. With a standard read/write
            interface to store data, it is now very simple to write third party
            applications (JavaScript/Mobile/other technologies) that can talk to
            your Spree store.
          </Section>

          <Section
            path="/developer"
            title="Developer Guides"
            className="w-50-ns"
          >
            This part of Spree’s documentation covers the technical aspects of
            Spree. If you are working with Rails and are building a Spree store,
            this is the documentation for you.
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
      </div>
    </div>
  </Layout>
)

export default IndexPage
