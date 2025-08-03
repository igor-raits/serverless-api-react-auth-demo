// Configuration file for AWS Amplify
// These values will be populated after terraform apply
export const awsConfig = {
  Auth: {
    Cognito: {
      userPoolId: import.meta.env.VITE_USER_POOL_ID || 'PLACEHOLDER_USER_POOL_ID',
      userPoolClientId: import.meta.env.VITE_USER_POOL_CLIENT_ID || 'PLACEHOLDER_CLIENT_ID',
      identityPoolId: import.meta.env.VITE_IDENTITY_POOL_ID || 'PLACEHOLDER_IDENTITY_POOL_ID',
      allowGuestAccess: true, // This is key for unauthenticated access
      loginWith: {
        oauth: {
          domain: import.meta.env.VITE_OAUTH_DOMAIN || 'PLACEHOLDER_DOMAIN',
          scopes: ['openid', 'email', 'profile'],
          redirectSignIn: [import.meta.env.VITE_REDIRECT_SIGN_IN || window.location.origin + '/callback'],
          redirectSignOut: [import.meta.env.VITE_REDIRECT_SIGN_OUT || window.location.origin + '/'],
          responseType: 'code'
        }
      }
    }
  },
  API: {
    REST: {
      IgorovoAPI: {
        endpoint: import.meta.env.VITE_API_ENDPOINT || 'PLACEHOLDER_API_ENDPOINT',
        region: import.meta.env.VITE_AWS_REGION || 'us-east-1'
      }
    }
  }
};
