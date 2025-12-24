import type { Metadata, Viewport } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'LiveLingo - Real-time Translation',
  description: 'Real-time speech translation powered by Gemini AI. Beautifully simple, instantly powerful.',
  keywords: ['translation', 'speech', 'AI', 'Gemini', 'real-time', 'LiveLingo'],
  authors: [{ name: 'LiveLingo Team' }],
  openGraph: {
    title: 'LiveLingo - Real-time Translation',
    description: 'Real-time speech translation powered by Gemini AI',
    type: 'website',
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'LiveLingo',
  },
  formatDetection: {
    telephone: false,
  },
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#000000' },
  ],
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@200;300;400;500;600;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="min-h-screen antialiased">
        <div className="fixed inset-0 -z-10 overflow-hidden">
          {/* Light Mode Background */}
          <div className="absolute inset-0 bg-white dark:bg-black" />

          {/* Subtle gradient overlay */}
          <div
            className="absolute inset-0 opacity-30 dark:opacity-20"
            style={{
              background: 'radial-gradient(circle at 30% 20%, rgba(59, 130, 246, 0.15) 0%, transparent 50%), radial-gradient(circle at 70% 80%, rgba(59, 130, 246, 0.1) 0%, transparent 50%)',
            }}
          />

          {/* Noise texture for depth (subtle) */}
          <div
            className="absolute inset-0 opacity-[0.015] dark:opacity-[0.025] mix-blend-overlay"
            style={{
              backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
            }}
          />
        </div>

        <main className="relative z-0">
          {children}
        </main>
      </body>
    </html>
  )
}
