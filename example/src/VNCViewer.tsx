import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import type { VncScreenHandle } from 'react-vnc'
import { VncScreen } from 'react-vnc'

interface VNCViewerProps {
  url: string
  password: string
  onDisconnect?: () => void
}

export interface VNCViewerHandle {
  disconnect: () => void
}

type ConnectionStatus = 'connecting' | 'connected' | 'disconnected' | 'error'

const VNCViewer = forwardRef<VNCViewerHandle, VNCViewerProps>(
  ({ url, password, onDisconnect }, ref) => {
    const [status, setStatus] = useState<ConnectionStatus>('connecting')
    const [errorMessage, setErrorMessage] = useState<string>('')
    const vncRef = useRef<VncScreenHandle>(null)

    useImperativeHandle(ref, () => ({
      disconnect: () => {
        if (vncRef.current?.disconnect) {
          vncRef.current.disconnect()
        }
        setStatus('disconnected')
        if (onDisconnect) {
          onDisconnect()
        }
      },
    }))

    return (
      <div style={{ position: 'relative', width: '100%', height: '100%' }}>
        {/* Status Overlay */}
        {status === 'connecting' && (
          <div style={overlayStyle}>
            <div style={spinnerStyle} />
            <p>Connecting to VNC desktop...</p>
          </div>
        )}

        {status === 'error' && (
          <div style={overlayStyle}>
            <p style={{ color: '#ff6b6b', marginBottom: '16px' }}>
              {errorMessage}
            </p>
          </div>
        )}

        {status === 'disconnected' && (
          <div style={overlayStyle}>
            <p>Disconnected from VNC desktop</p>
          </div>
        )}

        {/* VNC Screen */}
        <VncScreen
          ref={vncRef}
          url={url}
          scaleViewport
          background="#000"
          style={{
            width: '100%',
            height: '100%',
            minHeight: '600px',
          }}
          rfbOptions={{
            credentials: {
              password,
              username: '',
              target: '',
            },
          }}
          onConnect={() => {
            console.log('VNC connected successfully')
            setStatus('connected')
            setErrorMessage('')
          }}
          onDisconnect={(e) => {
            console.log('VNC disconnected:', e.detail)
            setStatus('disconnected')
            if (e.detail?.clean === false) {
              setErrorMessage('Connection lost unexpectedly')
            }
          }}
          onCredentialsRequired={() => {
            console.error('VNC credentials required')
            setErrorMessage('Invalid VNC password')
            setStatus('error')
          }}
          onSecurityFailure={(e) => {
            console.error('VNC security failure:', e.detail)
            setErrorMessage(
              `Security failure: ${e.detail?.status || 'Unknown'}`
            )
            setStatus('error')
          }}
        />
      </div>
    )
  }
)

VNCViewer.displayName = 'VNCViewer'

export default VNCViewer

// Styles
const overlayStyle: React.CSSProperties = {
  position: 'absolute',
  top: 0,
  left: 0,
  right: 0,
  bottom: 0,
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  background: 'rgba(0, 0, 0, 0.8)',
  color: 'white',
  zIndex: 10,
}

const spinnerStyle: React.CSSProperties = {
  border: '4px solid rgba(255, 255, 255, 0.3)',
  borderTop: '4px solid white',
  borderRadius: '50%',
  width: '40px',
  height: '40px',
  animation: 'spin 1s linear infinite',
  marginBottom: '16px',
}
