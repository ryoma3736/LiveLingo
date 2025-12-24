import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: 'media',
  theme: {
    extend: {
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          'SF Pro Display',
          'Inter',
          'system-ui',
          'sans-serif',
        ],
        display: ['SF Pro Display', 'Inter', 'system-ui', 'sans-serif'],
      },
      colors: {
        // Apple HIG Grayscale Palette
        gray: {
          50: '#FAFAFA',
          100: '#F5F5F5',
          200: '#EEEEEE',
          300: '#E0E0E0',
          400: '#BDBDBD',
          500: '#9E9E9E',
          600: '#757575',
          700: '#616161',
          800: '#424242',
          900: '#1C1C1E',
        },
        // Accent - Single blue (Apple-style)
        accent: {
          50: '#EBF5FF',
          100: '#E1EFFE',
          200: '#C3DDFD',
          300: '#A4CAFE',
          400: '#76A9FA',
          500: '#3B82F6',
          600: '#2563EB',
          700: '#1D4ED8',
          800: '#1E40AF',
          900: '#1E3A8A',
        },
        // Semantic colors
        success: '#34C759',
        warning: '#FF9500',
        error: '#FF3B30',
        // Glass morphism
        glass: {
          light: 'rgba(255, 255, 255, 0.72)',
          dark: 'rgba(28, 28, 30, 0.72)',
        },
      },
      spacing: {
        // 8pt Grid System
        '0.5': '0.125rem', // 2px
        '1': '0.25rem',    // 4px
        '1.5': '0.375rem', // 6px
        '2': '0.5rem',     // 8px
        '3': '0.75rem',    // 12px
        '4': '1rem',       // 16px
        '5': '1.25rem',    // 20px
        '6': '1.5rem',     // 24px
        '8': '2rem',       // 32px
        '10': '2.5rem',    // 40px
        '12': '3rem',      // 48px
        '16': '4rem',      // 64px
        '20': '5rem',      // 80px
        '24': '6rem',      // 96px
        '32': '8rem',      // 128px
        '40': '10rem',     // 160px
        '48': '12rem',     // 192px
        '56': '14rem',     // 224px
        '64': '16rem',     // 256px
      },
      maxWidth: {
        // Golden Ratio containers
        'container-xs': '20rem',    // 320px
        'container-sm': '32.5rem',  // 520px
        'container-md': '52.5rem',  // 840px (520 * 1.618)
        'container-lg': '85rem',    // 1360px (840 * 1.618)
        'container-xl': '137.5rem', // 2200px (1360 * 1.618)
      },
      boxShadow: {
        // Apple-style elevation system
        'depth-1': '0 1px 3px rgba(0, 0, 0, 0.12)',
        'depth-2': '0 3px 6px rgba(0, 0, 0, 0.15)',
        'depth-3': '0 10px 20px rgba(0, 0, 0, 0.15)',
        'depth-4': '0 15px 25px rgba(0, 0, 0, 0.15)',
        'depth-5': '0 20px 40px rgba(0, 0, 0, 0.2)',
        'inner-glow': 'inset 0 0 0 1px rgba(255, 255, 255, 0.1)',
        'glass': '0 8px 32px rgba(0, 0, 0, 0.12)',
      },
      borderRadius: {
        'apple': '12px',
        'apple-lg': '16px',
        'apple-xl': '24px',
      },
      backdropBlur: {
        'xs': '2px',
        'sm': '4px',
        'DEFAULT': '8px',
        'md': '12px',
        'lg': '16px',
        'xl': '24px',
        '2xl': '40px',
        '3xl': '64px',
      },
      animation: {
        // Apple-style animations
        'breathe': 'breathe 2s cubic-bezier(0.4, 0, 0.2, 1) infinite',
        'pulse-subtle': 'pulse-subtle 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'slide-up': 'slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1)',
        'slide-down': 'slide-down 0.4s cubic-bezier(0.16, 1, 0.3, 1)',
        'fade-in': 'fade-in 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
        'scale-in': 'scale-in 0.2s cubic-bezier(0.16, 1, 0.3, 1)',
      },
      keyframes: {
        breathe: {
          '0%, 100%': { opacity: '1', transform: 'scale(1)' },
          '50%': { opacity: '0.85', transform: 'scale(0.98)' },
        },
        'pulse-subtle': {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.92' },
        },
        'slide-up': {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        'slide-down': {
          '0%': { transform: 'translateY(-10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'scale-in': {
          '0%': { transform: 'scale(0.95)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
      },
      transitionTimingFunction: {
        'apple': 'cubic-bezier(0.16, 1, 0.3, 1)',
        'apple-smooth': 'cubic-bezier(0.4, 0, 0.2, 1)',
      },
      letterSpacing: {
        'tighter': '-0.05em',
        'tight': '-0.025em',
        'apple': '-0.022em',
      },
    },
  },
  plugins: [],
}

export default config
