# VNC Lab Desktop - React Example

A simple React + Vite application demonstrating how to connect to the VNC Lab Desktop using noVNC.

## Prerequisites

1. **Start the VNC container:**

```bash
docker run -d \
  -p 6080:6080 \
  -e VNC_PASSWORD=password \
  --name vnc-desktop \
  usersina/vnc-lab-desktop:latest
```

2. **Install dependencies:**

```bash
npm install
```

## Running the Example

```bash
npm run dev
```

Then open <http://localhost:5173> in your browser.

## Usage

1. The default VNC URL is `ws://localhost:6080`
2. The default password is `password` (matches the Docker container)
3. Click "Connect to Desktop" to establish the connection
4. You should see the MATE desktop environment in your browser

## Configuration

You can change the VNC URL and password in the connection form:

- **VNC URL**: The WebSocket endpoint (default: `ws://localhost:6080`)
- **Password**: The VNC password set when starting the container

## How It Works

This example uses:

- **React**: UI framework
- **Vite**: Build tool and dev server
- **react-vnc**: React wrapper for noVNC client library
- **TypeScript**: Type safety

The main components:

- `VNCViewer.tsx`: The VNC viewer component that handles the connection
- `App.tsx`: The main application with connection form
- `index.css`: All the styling

## Troubleshooting

### Connection Refused

Make sure the VNC container is running:

```bash
docker ps | grep vnc-desktop
```

### Black Screen

Wait 15-20 seconds for the desktop to fully start, then refresh the page.

### Invalid Password

Ensure the password in the form matches the `VNC_PASSWORD` environment variable set when starting the container.

## Integration

To use this in your own project:

1. Install react-vnc: `npm install react-vnc`
2. Copy the `VNCViewer.tsx` component
3. Use it in your React app:

```tsx
import { useRef } from 'react'
import VNCViewer, { VNCViewerHandle } from './VNCViewer'

function App() {
  const vncRef = useRef<VNCViewerHandle>(null)

  const handleDisconnect = () => {
    vncRef.current?.disconnect()
  }

  return (
    <div style={{ width: '100vw', height: '100vh' }}>
      <VNCViewer
        ref={vncRef}
        url="ws://localhost:6080"
        password="password"
        onDisconnect={() => console.log('Disconnected')}
      />
      <button onClick={handleDisconnect}>Disconnect</button>
    </div>
  )
}
```

## Learn More

- [react-vnc GitHub](https://github.com/roerohan/react-vnc)
- [noVNC Documentation](https://github.com/novnc/noVNC)
- [VNC Lab Desktop Repository](https://github.com/usersina/vnc-lab-desktop)

---

## ESLint Configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...

      // Remove tseslint.configs.recommended and replace with this
      tseslint.configs.recommendedTypeChecked,
      // Alternatively, use this for stricter rules
      tseslint.configs.strictTypeChecked,
      // Optionally, add this for stylistic rules
      tseslint.configs.stylisticTypeChecked,

      // Other configs...
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x'
import reactDom from 'eslint-plugin-react-dom'

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs['recommended-typescript'],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```
