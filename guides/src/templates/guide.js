import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { graphql } from 'gatsby'

import Layout from '../components/Layout'

export default function Template({ data }) {
  const { guide } = data

  return (
    <Layout
      nav={data.sidebarNav ? data.sidebarNav.group : []}
      activeSection={guide.fields.section}
      activeRootSection={guide.fields.rootSection}
    >
      <div className="guide-container">
        <Helmet title={`Spree Guides :: ${guide.frontmatter.title}`} />
        <div className="guide">
          <h1>{guide.frontmatter.title}</h1>
          <div
            className="guide-content"
            dangerouslySetInnerHTML={{ __html: guide.html }}
          />
        </div>
      </div>
    </Layout>
  )
}

Template.propTypes = {
  data: PropTypes.object.isRequired
}

export const pageQuery = graphql`
  query GuideById($id: String, $rootSection: String) {
    sidebarNav: allMarkdownRemark(
      filter: {
        fields: { rootSection: { eq: $rootSection }, section: { ne: "null" } }
      }
      sort: { fields: [frontmatter___title], order: DESC }
    ) {
      group(field: fields___section) {
        section: fieldValue
        edges {
          node {
            fields {
              section
              slug
              rootSection
              isIndex
            }
            frontmatter {
              title
            }
          }
        }
      }
    }
    guide: markdownRemark(id: { eq: $id }) {
      fields {
        section
        rootSection
      }
      html
      frontmatter {
        title
      }
    }
  }
`
