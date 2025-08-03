import React from 'react'
import { createRoot } from 'react-dom/client'
import { Amplify } from 'aws-amplify'
import App from './App.jsx'
import { awsConfig } from './config.js'
import './index.css'

// Configure Amplify
Amplify.configure(awsConfig)

const container = document.getElementById('root')
const root = createRoot(container)

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
