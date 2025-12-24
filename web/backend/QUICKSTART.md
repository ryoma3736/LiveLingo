# LiveLingo Backend - Quick Start Guide

Get your LiveLingo backend up and running in 5 minutes!

## Option 1: Automated Setup (Recommended)

### Prerequisites
- Docker Desktop installed and running
- Node.js 18+ installed

### Steps

1. **Run the setup script:**
   ```bash
   chmod +x scripts/setup-db.sh
   ./scripts/setup-db.sh
   ```

2. **Start the development server:**
   ```bash
   npm run dev
   ```

3. **Verify everything is working:**
   - API: http://localhost:3001/api
   - Health check: http://localhost:3001/health
   - Prisma Studio: `npm run db:studio`
   - pgAdmin: http://localhost:5050

That's it! Your backend is ready.

---

## Option 2: Manual Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Start PostgreSQL

**Using Docker (Recommended):**
```bash
docker-compose up -d postgres
```

**Using existing PostgreSQL:**
- Ensure PostgreSQL is running
- Create a database named `livelingo`

### 3. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and update `DATABASE_URL`:

```env
# For Docker:
DATABASE_URL="postgresql://livelingo:livelingo_dev_password@localhost:5432/livelingo?schema=public"

# For local PostgreSQL:
DATABASE_URL="postgresql://your_user:your_password@localhost:5432/livelingo?schema=public"
```

### 4. Setup Database

```bash
# Generate Prisma Client
npm run db:generate

# Push schema to database
npm run db:push

# Seed with sample data (optional)
npm run db:seed
```

### 5. Start Development Server

```bash
npm run dev
```

---

## Verification

### Check API Health
```bash
curl http://localhost:3001/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2025-12-24T...",
  "database": {
    "status": "healthy",
    "responseTime": "5ms",
    "timestamp": "2025-12-24T..."
  }
}
```

### Explore Database with Prisma Studio
```bash
npm run db:studio
```

Opens a GUI at http://localhost:5555

### Query Sample Data

```bash
# Install Prisma CLI globally (optional)
npx prisma studio
```

You should see:
- 2 Users (1 demo user, 1 guest)
- 1 Conversation with 3 Transcripts
- 2 Settings records

---

## Common Commands

```bash
# Development
npm run dev              # Start dev server with hot reload

# Database
npm run db:studio        # Open Prisma Studio GUI
npm run db:seed          # Seed database with sample data
npm run db:reset         # Reset database (WARNING: deletes all data)
npm run db:migrate       # Create and run migration

# Docker
docker-compose up -d     # Start PostgreSQL + pgAdmin
docker-compose down      # Stop containers
docker-compose logs -f   # View logs
```

---

## Troubleshooting

### "Can't reach database server"

**Solution 1:** Check if PostgreSQL is running
```bash
docker-compose ps
```

**Solution 2:** Verify DATABASE_URL in .env
```bash
cat .env | grep DATABASE_URL
```

**Solution 3:** Restart containers
```bash
docker-compose down
docker-compose up -d
```

### "Port 5432 already in use"

You have another PostgreSQL instance running.

**Option A:** Stop existing PostgreSQL
```bash
# macOS
brew services stop postgresql

# Linux
sudo systemctl stop postgresql
```

**Option B:** Change port in docker-compose.yml
```yaml
ports:
  - '5433:5432'  # Use port 5433 instead
```

Then update DATABASE_URL:
```env
DATABASE_URL="postgresql://livelingo:livelingo_dev_password@localhost:5433/livelingo?schema=public"
```

### "Module not found"

Install dependencies:
```bash
npm install
```

### Prisma Client errors

Regenerate Prisma Client:
```bash
npm run db:generate
```

---

## Next Steps

1. **Explore the API:**
   - Check `/api` endpoint for available routes
   - Read API documentation in README.md

2. **Build features:**
   - Implement user authentication
   - Add conversation endpoints
   - Create transcript API

3. **Connect frontend:**
   - Update frontend API URL to `http://localhost:3001`
   - Implement API client

4. **Deploy:**
   - Use managed PostgreSQL (e.g., Supabase, Railway)
   - Deploy backend to Vercel/Railway/Render

---

## Resources

- [Prisma Documentation](https://www.prisma.io/docs)
- [Express.js Guide](https://expressjs.com/en/guide/routing.html)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

---

Happy coding! 🚀
