// --- Dependencies
import * as React from 'react'
import { StaticQuery, graphql } from 'gatsby'
import Img from 'gatsby-image'

/**
 * Component
 */

const Logo = () => (
  <StaticQuery
    query={graphql`
      query {
        placeholderImage: file(relativePath: { eq: "logo-spark.png" }) {
          childImageSharp {
            fixed(height: 100) {
              ...GatsbyImageSharpFixed_withWebp_noBase64
            }
          }
        }
      }
    `}
    render={data => (
      <Img
        critical
        alt="Spark Solutions"
        fadeIn={false}
        fixed={data.placeholderImage.childImageSharp.fixed}
      />
    )}
  />
)

export default Logo
