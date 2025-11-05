import { useRef, useState } from 'react'
import type { VNCViewerHandle } from './VNCViewer'
import VNCViewer from './VNCViewer'

function App() {
  const [vncUrl, setVncUrl] = useState('ws://localhost:6080')
  const [vncPassword, setVncPassword] = useState('password')
  const [isConnected, setIsConnected] = useState(false)
  const vncViewerRef = useRef<VNCViewerHandle>(null)

  const handleConnect = (e: React.FormEvent) => {
    e.preventDefault()
    setIsConnected(true)
  }

  const handleDisconnect = () => {
    vncViewerRef.current?.disconnect()
    setIsConnected(false)
  }

  if (isConnected) {
    return (
      <div className="app">
        <header className="app-header">
          <h1>VNC Lab Desktop</h1>
          <div className="controls">
            <span className="url-display">{vncUrl}</span>
            <button onClick={handleDisconnect} className="disconnect-btn">
              Disconnect
            </button>
          </div>
        </header>
        <main className="vnc-container">
          <VNCViewer
            ref={vncViewerRef}
            url={vncUrl}
            password={vncPassword}
            onDisconnect={() => setIsConnected(false)}
          />
        </main>
      </div>
    )
  }

  return (
    <div className="app">
      <div className="connection-form-container">
        <div className="connection-form-card">
          <h1>🖥️ VNC Lab Desktop</h1>
          <p className="subtitle">
            Connect to your browser-based Linux desktop environment
          </p>

          <form onSubmit={handleConnect} className="connection-form">
            <div className="form-group">
              <label htmlFor="vncUrl">VNC WebSocket URL</label>
              <input
                type="text"
                id="vncUrl"
                value={vncUrl}
                onChange={(e) => setVncUrl(e.target.value)}
                placeholder="ws://localhost:6080"
                required
              />
              <small>Default: ws://localhost:6080</small>
            </div>

            <div className="form-group">
              <label htmlFor="vncPassword">VNC Password</label>
              <input
                type="password"
                id="vncPassword"
                value={vncPassword}
                onChange={(e) => setVncPassword(e.target.value)}
                placeholder="Enter VNC password"
                required
              />
              <small>Default password: password</small>
            </div>

            <button type="submit" className="connect-btn">
              Connect to Desktop
            </button>
          </form>

          <div className="instructions">
            <h3>📝 Quick Start</h3>
            <ol>
              <li>
                Start the VNC container:
                <pre>
                  docker run -d -p 6080:6080 -e VNC_PASSWORD=password
                  usersina/vnc-lab-desktop
                </pre>
              </li>
              <li>Enter the VNC URL and password above</li>
              <li>Click "Connect to Desktop"</li>
            </ol>
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
