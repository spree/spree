import * as React from 'react'
import PropTypes from 'prop-types'
import { graphql } from 'gatsby'

import Layout from '../components/Layout'

const ApiPage = ({
  data: {
    sidebarNav: { group: nav },
    indexContent
  }
}) => (
  <Layout nav={nav}>
    <h1>Api</h1>
    <div
      dangerouslySetInnerHTML={{
        __html: indexContent.html
      }}
    />
  </Layout>
)

ApiPage.propTypes = {
  data: PropTypes.shape({
    allMarkdownRemark: PropTypes.shape({
      edges: PropTypes.arrayOf(
        PropTypes.shape({
          node: PropTypes.shape({
            html: PropTypes.string.isRequired
          })
        })
      )
    })
  })
}

export default ApiPage

export const pageQuery = graphql`
  query {
    site {
      siteMetadata {
        title
      }
    }
    sidebarNav: allFile(
      filter: {
        ext: { eq: ".md" }
        base: { ne: "index.md" }
        relativeDirectory: { glob: "api" }
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
    indexContent: markdownRemark(frontmatter: { title: { eq: "API" } }) {
      frontmatter {
        title
      }
      html
    }
  }
`
