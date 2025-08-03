import React, { useEffect } from 'react'

const CallbackPage = () => {
  useEffect(() => {
    // This page handles the OAuth redirect
    // Amplify will automatically process the callback
    console.log('OAuth callback received')

    // Redirect to main page after a short delay
    const timer = setTimeout(() => {
      window.location.href = '/'
    }, 1000)

    return () => clearTimeout(timer)
  }, [])

  return (
    <div className="container">
      <div className="header">
        <h1>Processing Login...</h1>
        <p className="loading">Please wait while we complete your sign-in...</p>
      </div>
    </div>
  )
}

export default CallbackPage
