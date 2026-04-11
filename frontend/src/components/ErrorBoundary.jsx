import React from 'react'

export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props)
    this.state = { hasError: false, error: null }
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error }
  }

  componentDidCatch(error, errorInfo) {
    console.error('AN·RA UI Error:', error, errorInfo)
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="error-boundary" style={{
          height: '100vh',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          fontFamily: 'var(--font-mono)',
          color: 'var(--hi)'
        }}>
          <h2>TRUMAN ENCOUNTERED A FAILURE</h2>
          <p style={{ color: 'var(--red)' }}>{this.state.error?.message}</p>
          <button 
            onClick={() => window.location.reload()}
            style={{
              marginTop: '1rem',
              padding: '0.5rem 1rem',
              background: 'var(--red)',
              color: 'var(--base)',
              border: 'none',
              cursor: 'pointer'
            }}
          >
            REBOOT INTERFACE
          </button>
        </div>
      )
    }

    return this.props.children
  }
}

export default ErrorBoundary
