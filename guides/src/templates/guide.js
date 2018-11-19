import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { graphql } from 'gatsby'

import Layout from '../components/Layout'

export default function Template({ data }) {
  const { guide } = data

  console.log(guide)

  return (
    <Layout nav={data.sidebarNav ? data.sidebarNav.group : []}>
      <div className="guide-container">
        <Helmet title={`Spree Guides :: ${guide.frontmatter.title}`} />
        <div className="guide">
          {console.log(data)}
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
    ) {
      group(field: fields___section) {
        section: fieldValue
        edges {
          node {
            fields {
              section
              slug
              rootSection
            }
            frontmatter {
              title
            }
          }
        }
      }
    }
    guide: markdownRemark(id: { eq: $id }) {
      id
      html
      frontmatter {
        title
      }
    }
  }
`
