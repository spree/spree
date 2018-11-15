import * as React from 'react'
import PropTypes from 'prop-types'
import Helmet from 'react-helmet'
import { graphql } from 'gatsby'

import Layout from '../components/Layout'

export default function Template({ data }) {
  const { markdownRemark: guide } = data
  console.log(data.sidebarNav.group)
  return (
    <Layout nav={data.sidebarNav ? data.sidebarNav.group : []}>
      <div className="blog-guide-container">
        <Helmet title={`Spree Guides :: ${guide.frontmatter.title}`} />
        <div className="blog-guide">
          <h1>{guide.frontmatter.title}</h1>
          <div
            className="blog-guide-content"
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
  query GuideById($id: String!, $section: String!) {
    sidebarNav: allFile(
      filter: {
        ext: { eq: ".md" }
        base: { ne: "index.md" }
        relativeDirectory: { glob: $section }
      }
    ) {
      group(field: relativeDirectory) {
        section: fieldValue
        edges {
          node {
            relativePath
            childMarkdownRemark {
              frontmatter {
                title
              }
            }
          }
        }
      }
    }
    markdownRemark(id: { eq: $id }) {
      html
      frontmatter {
        title
      }
    }
  }
`
