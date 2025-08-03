import React, { useState, useEffect } from 'react'
import { signInWithRedirect, signOut, getCurrentUser, fetchAuthSession } from 'aws-amplify/auth'
import { get } from 'aws-amplify/api'
import { jwtDecode } from 'jwt-decode'
import CallbackPage from './CallbackPage.jsx'

const App = () => {
  const [user, setUser] = useState(null)
  const [tokens, setTokens] = useState(null)
  const [loading, setLoading] = useState(true)
  const [apiResponse, setApiResponse] = useState('')
  const [apiLoading, setApiLoading] = useState(false)
  const [cachedSession, setCachedSession] = useState(null) // Cache session to avoid redundant calls

  // Handle OAuth callback route
  if (window.location.pathname === '/callback') {
    return <CallbackPage />
  }

  useEffect(() => {
    checkAuthState()
  }, [])

  const checkAuthState = async () => {
    try {
      setLoading(true)
      const currentUser = await getCurrentUser()
      setUser(currentUser)

      const session = await fetchAuthSession()
      setTokens(session.tokens)
      setCachedSession(session) // Cache the session

      // Debug: Always check what credentials we have
      console.log('Initial auth check:', {
        hasUser: !!currentUser,
        hasTokens: !!session.tokens,
        hasCredentials: !!session.credentials,
        identityId: session.identityId
      })
    } catch (error) {
      console.log('User not authenticated:', error)
      setUser(null)
      setTokens(null)
      setCachedSession(null) // Clear cached session

      // Even when not authenticated, we should get unauthenticated credentials
      try {
        const unauthSession = await fetchAuthSession()
        console.log('Unauthenticated session check:', {
          hasCredentials: !!unauthSession.credentials,
          identityId: unauthSession.identityId
        })
      } catch (credError) {
        console.error('Failed to get unauthenticated credentials:', credError)
      }
    } finally {
      setLoading(false)
    }
  }

  const handleSignIn = async () => {
    try {
      // Debug: Log the current Amplify configuration
      console.log('Amplify config check:', {
        domain: import.meta.env.VITE_OAUTH_DOMAIN,
        redirectSignIn: import.meta.env.VITE_REDIRECT_SIGN_IN,
        redirectSignOut: import.meta.env.VITE_REDIRECT_SIGN_OUT
      })

      // For Amplify v6 with Cognito Managed Login, use this pattern
      await signInWithRedirect()
    } catch (error) {
      console.error('Sign in error:', error)
    }
  }

  const handleSignOut = async () => {
    try {
      await signOut()
      setUser(null)
      setTokens(null)
      setCachedSession(null) // Clear cached session
      setApiResponse('')
    } catch (error) {
      console.error('Sign out error:', error)
    }
  }

  const callAPI = async (endpoint, useIAM = false) => {
    setApiLoading(true)
    setApiResponse('')

    try {
      if (useIAM) {
        // Use cached session first, only fetch if not available or expired
        let session = cachedSession

        // Check if we need to refresh the session
        if (!session || !session.credentials) {
          console.log('Fetching fresh session (no cached credentials)')
          session = await fetchAuthSession()
          setCachedSession(session)
        } else {
          // Check if credentials are close to expiring (refresh 5 minutes before expiry)
          const expiration = session.credentials.expiration
          const fiveMinutesFromNow = new Date(Date.now() + 5 * 60 * 1000)

          if (expiration && expiration < fiveMinutesFromNow) {
            console.log('Refreshing session (credentials expiring soon)')
            session = await fetchAuthSession()
            setCachedSession(session)
          } else {
            console.log('Using cached session (credentials still valid)')
          }
        }

        console.log('Session credentials:', {
          hasCredentials: !!session.credentials,
          isAuthenticated: !!user,
          credentialsType: session.credentials ? 'Available' : 'None',
          identityId: session.identityId,
          hasIdToken: !!tokens?.idToken,
          expiresAt: session.credentials?.expiration?.toISOString()
        })

        if (!session.credentials) {
          throw new Error('No AWS credentials available - Identity Pool might not be configured correctly')
        }

        // Build headers for the request
        const headers = {}

        // For authenticated users, add the ID token header
        if (user && tokens?.idToken) {
          headers['X-Cognito-Id-Token'] = tokens.idToken.toString()
          console.log('Adding ID token header for authenticated call')
        }

        // Use Amplify's REST client with custom headers
        const restOperation = get({
          apiName: 'IgorovoAPI',
          path: endpoint,
          options: {
            headers: headers
          }
        })

        const response = await restOperation.response
        const data = await response.body.text()
        setApiResponse(`Status: ${response.statusCode}\n\n${data}`)
      } else {
        // Use regular fetch for non-IAM endpoints
        const baseUrl = import.meta.env.VITE_API_ENDPOINT || 'PLACEHOLDER_API_ENDPOINT'
        const url = `${baseUrl}${endpoint}`

        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
          }
        })

        const data = await response.text()
        setApiResponse(`Status: ${response.status}\n\n${data}`)
      }
    } catch (error) {
      console.error('API call error:', error)
      setApiResponse(`Error: ${error.message}`)
    } finally {
      setApiLoading(false)
    }
  }

  const formatTokenPayload = (token) => {
    if (!token) return 'No token available'

    try {
      const decoded = jwtDecode(token)
      return JSON.stringify(decoded, null, 2)
    } catch (error) {
      return `Error decoding token: ${error.message}`
    }
  }

  if (loading) {
    return (
      <div className="container">
        <div className="header">
          <h1>Cognito Authentication Demo</h1>
          <p className="loading">Loading...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="container">
      <div className="header">
        <h1>Cognito Authentication Demo</h1>
        <p>React 19 + Vite app with AWS Cognito Hosted UI integration</p>
      </div>

      <div className="auth-section">
        <h2>Authentication Status</h2>
        {user ? (
          <div className="user-info">
            <h3>✅ Authenticated User</h3>
            <p><strong>User ID:</strong> {user.userId}</p>
            <p><strong>Username:</strong> {user.username}</p>
            {user.signInDetails && (
              <p><strong>Sign In Method:</strong> {user.signInDetails.loginId}</p>
            )}
            <button className="button secondary" onClick={handleSignOut}>
              Sign Out
            </button>
          </div>
        ) : (
          <div>
            <p>You are not authenticated. Please sign in to continue.</p>
            <button className="button" onClick={handleSignIn}>
              Sign In with Cognito Hosted UI
            </button>
          </div>
        )}
      </div>

      {tokens && (
        <div className="token-section">
          <h2>JWT Tokens</h2>

          <div className="grid">
            <div>
              <h3>ID Token</h3>
              <div className="token-display">
                {tokens.idToken?.toString() || 'No ID token'}
              </div>
              <div className="token-decoded">
                <h4>Decoded Payload:</h4>
                <pre>{formatTokenPayload(tokens.idToken?.toString())}</pre>
              </div>
            </div>

            <div>
              <h3>Access Token</h3>
              <div className="token-display">
                {tokens.accessToken?.toString() || 'No access token'}
              </div>
              <div className="token-decoded">
                <h4>Decoded Payload:</h4>
                <pre>{formatTokenPayload(tokens.accessToken?.toString())}</pre>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="api-section">
        <h2>API Testing</h2>
        <p>Test your API endpoints with different authorization levels:</p>

        <div className="grid">
          <button
            className="button"
            onClick={() => callAPI('/test/plain')}
            disabled={apiLoading}
          >
            Call Public Endpoint
          </button>

          <button
            className="button"
            onClick={() => callAPI('/test/public', true)}
            disabled={apiLoading}
          >
            Call Public with IAM
          </button>

          <button
            className="button"
            onClick={() => callAPI('/test/auth', true)}
            disabled={apiLoading}
          >
            Call Authenticated Endpoint
          </button>
        </div>

        {apiLoading && <p className="loading">Calling API...</p>}

        {apiResponse && (
          <div className="api-response">
            <h4>API Response:</h4>
            {apiResponse}
          </div>
        )}
      </div>

      <div className="token-section">
        <h2>Configuration Info</h2>
        <div className="token-display">
          <strong>Environment Variables (Vite):</strong><br />
          User Pool ID: {import.meta.env.VITE_USER_POOL_ID || 'Not set'}<br />
          Client ID: {import.meta.env.VITE_USER_POOL_CLIENT_ID || 'Not set'}<br />
          Identity Pool ID: {import.meta.env.VITE_IDENTITY_POOL_ID || 'Not set'}<br />
          OAuth Domain: {import.meta.env.VITE_OAUTH_DOMAIN || 'Not set'}<br />
          API Endpoint: {import.meta.env.VITE_API_ENDPOINT || 'Not set'}<br />
        </div>
        <div className="token-display" style={{ marginTop: '1rem' }}>
          <strong>Tech Stack:</strong><br />
          React: {React.version || '19.x'}<br />
          Build Tool: Vite<br />
          AWS Amplify: v6.x<br />
        </div>
      </div>
    </div>
  )
}

export default App
