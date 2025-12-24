#!/bin/bash

# LiveLingo Database Setup Script

set -e

echo "🚀 LiveLingo Database Setup"
echo "============================"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please update DATABASE_URL in .env file"
    echo ""
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

echo "🐘 Starting PostgreSQL with Docker..."
docker-compose up -d postgres

echo ""
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Wait for PostgreSQL to be healthy
until docker-compose exec -T postgres pg_isready -U livelingo > /dev/null 2>&1; do
    echo "   Waiting for PostgreSQL..."
    sleep 2
done

echo "✅ PostgreSQL is ready!"
echo ""

# Update .env with Docker database URL
echo "📝 Updating DATABASE_URL in .env..."
if grep -q "DATABASE_URL=" .env; then
    sed -i.bak 's|DATABASE_URL=.*|DATABASE_URL="postgresql://livelingo:livelingo_dev_password@localhost:5432/livelingo?schema=public"|' .env
    rm -f .env.bak
fi

echo ""
echo "📦 Installing dependencies..."
npm install

echo ""
echo "🔨 Generating Prisma Client..."
npm run db:generate

echo ""
echo "🗄️  Pushing schema to database..."
npm run db:push

echo ""
echo "🌱 Seeding database..."
npm run db:seed

echo ""
echo "✅ Database setup complete!"
echo ""
echo "📊 Database Information:"
echo "   Host: localhost"
echo "   Port: 5432"
echo "   Database: livelingo"
echo "   User: livelingo"
echo "   Password: livelingo_dev_password"
echo ""
echo "🎨 pgAdmin is available at: http://localhost:5050"
echo "   Email: admin@livelingo.app"
echo "   Password: admin"
echo ""
echo "🚀 Start the development server with:"
echo "   npm run dev"
echo ""
echo "🔍 Open Prisma Studio with:"
echo "   npm run db:studio"
