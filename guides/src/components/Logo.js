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
        placeholderImage: file(relativePath: { eq: "logo.png" }) {
          childImageSharp {
            fixed(height: 50) {
              ...GatsbyImageSharpFixed_withWebp_noBase64
            }
          }
        }
      }
    `}
    render={data => (
      <Img
        alt="Spree Commerce - Ruby on Rails e-commerce platform"
        fadeIn={false}
        fixed={data.placeholderImage.childImageSharp.fixed}
      />
    )}
  />
)

export default Logo
