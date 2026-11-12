// The RFC 9728 document an MCP client reads before it has any credential,
// to discover which authorization server to send the merchant to. It is
// public and unauthenticated, so it is fetched directly rather than through
// the SDK.

// region:example
const response = await fetch('https://your-store.com/api/v3/oauth/protected-resource/admin')
const metadata = await response.json()

// endregion:example

export { metadata }
