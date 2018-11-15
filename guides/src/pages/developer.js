import * as React from 'react'
import PropTypes from 'prop-types'
import { graphql } from 'gatsby'

import Layout from '../components/Layout'

const DeveloperPage = ({
  data: {
    sidebarNav: { group: nav },
    indexContent
  }
}) => (
  <Layout nav={nav}>
    <h1>Developer</h1>
    <div
      dangerouslySetInnerHTML={{
        __html: indexContent.html
      }}
    />
  </Layout>
)

DeveloperPage.propTypes = {
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

export default DeveloperPage

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
        relativeDirectory: { glob: "developer/*" }
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
    indexContent: markdownRemark(
      frontmatter: { title: { eq: "Spree Developer Documentation" } }
    ) {
      frontmatter {
        title
      }
      html
    }
  }
`
