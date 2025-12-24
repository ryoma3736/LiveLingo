# LiveLingo Backend API

Backend API for LiveLingo Web App with PostgreSQL database and Prisma ORM.

## Prerequisites

- Node.js 18+
- PostgreSQL 14+
- npm or yarn

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Database Configuration

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Update the `DATABASE_URL` with your PostgreSQL credentials:

```env
DATABASE_URL="postgresql://username:password@localhost:5432/livelingo?schema=public"
```

### 3. Database Migration

```bash
# Generate Prisma Client
npm run db:generate

# Push schema to database
npm run db:push

# Or run migrations (recommended for production)
npm run db:migrate
```

### 4. Seed Database (Optional)

```bash
npm run db:seed
```

This creates:
- Demo user with email `demo@livelingo.app`
- Sample conversation with 3 transcripts
- Guest user without email

## Development

### Start Development Server

```bash
npm run dev
```

### Database Commands

```bash
# Generate Prisma Client
npm run db:generate

# Push schema changes (dev)
npm run db:push

# Create migration
npm run db:migrate

# Deploy migrations (production)
npm run db:migrate:deploy

# Open Prisma Studio (GUI)
npm run db:studio

# Seed database
npm run db:seed

# Reset database (WARNING: deletes all data)
npm run db:reset
```

### Build for Production

```bash
npm run build
npm start
```

## Database Schema

### User
- `id`: Unique identifier (CUID)
- `email`: Optional email (unique)
- `createdAt`, `updatedAt`: Timestamps
- Relations: `settings`, `conversations`

### Settings
- `id`: Unique identifier (CUID)
- `userId`: Foreign key to User
- `sourceLanguage`: Default source language (default: "ja")
- `targetLanguage`: Default target language (default: "en")
- `autoPlay`: Auto-play audio (default: true)
- `speechRate`: Speech rate multiplier (default: 1.0)
- `geminiApiKey`: Optional API key
- `createdAt`, `updatedAt`: Timestamps

### Conversation
- `id`: Unique identifier (CUID)
- `userId`: Foreign key to User
- `title`: Optional conversation title
- `createdAt`, `updatedAt`: Timestamps
- Relations: `transcripts`

### Transcript
- `id`: Unique identifier (CUID)
- `conversationId`: Foreign key to Conversation
- `speaker`: Speaker identifier (default: "user")
- `sourceText`: Original text
- `translatedText`: Translated text
- `sourceLanguage`: Source language code
- `targetLanguage`: Target language code
- `audioUrl`: Optional audio file URL
- `createdAt`: Timestamp

## API Endpoints (To be implemented)

### Users
- `POST /api/users` - Create user
- `GET /api/users/:id` - Get user by ID
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

### Settings
- `GET /api/users/:userId/settings` - Get user settings
- `PUT /api/users/:userId/settings` - Update user settings

### Conversations
- `GET /api/conversations` - List conversations
- `POST /api/conversations` - Create conversation
- `GET /api/conversations/:id` - Get conversation with transcripts
- `PUT /api/conversations/:id` - Update conversation
- `DELETE /api/conversations/:id` - Delete conversation

### Transcripts
- `POST /api/conversations/:id/transcripts` - Add transcript
- `GET /api/transcripts/:id` - Get transcript by ID
- `DELETE /api/transcripts/:id` - Delete transcript

## Project Structure

```
backend/
├── prisma/
│   ├── schema.prisma       # Database schema
│   └── seed.ts             # Seed data
├── src/
│   ├── lib/
│   │   └── prisma.ts       # Prisma client singleton
│   ├── routes/             # API routes (to be implemented)
│   ├── controllers/        # Route controllers (to be implemented)
│   └── index.ts            # Express app entry point
├── .env.example            # Environment variables template
├── package.json            # Dependencies and scripts
├── tsconfig.json           # TypeScript configuration
└── README.md               # This file
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `NODE_ENV` | Environment (development/production) | No |
| `PORT` | API server port | No |
| `GEMINI_API_KEY` | Default Gemini API key | No |

## License

MIT
