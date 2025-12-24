import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seeding...');

  // Create demo user
  const demoUser = await prisma.user.upsert({
    where: { email: 'demo@livelingo.app' },
    update: {},
    create: {
      email: 'demo@livelingo.app',
      settings: {
        create: {
          sourceLanguage: 'ja',
          targetLanguage: 'en',
          autoPlay: true,
          speechRate: 1.0,
        },
      },
    },
  });

  console.log('✅ Created demo user:', demoUser.id);

  // Create sample conversation
  const conversation = await prisma.conversation.create({
    data: {
      userId: demoUser.id,
      title: 'Sample Conversation',
      transcripts: {
        create: [
          {
            speaker: 'user',
            sourceText: 'こんにちは',
            translatedText: 'Hello',
            sourceLanguage: 'ja',
            targetLanguage: 'en',
          },
          {
            speaker: 'system',
            sourceText: 'Hello, how can I help you today?',
            translatedText: 'こんにちは、今日はどのようにお手伝いできますか？',
            sourceLanguage: 'en',
            targetLanguage: 'ja',
          },
          {
            speaker: 'user',
            sourceText: '英語の勉強をしたいです',
            translatedText: 'I want to study English',
            sourceLanguage: 'ja',
            targetLanguage: 'en',
          },
        ],
      },
    },
    include: {
      transcripts: true,
    },
  });

  console.log('✅ Created sample conversation:', conversation.id);
  console.log(`   - Created ${conversation.transcripts.length} transcripts`);

  // Create guest user (no email)
  const guestUser = await prisma.user.create({
    data: {
      settings: {
        create: {
          sourceLanguage: 'en',
          targetLanguage: 'es',
          autoPlay: false,
          speechRate: 0.9,
        },
      },
    },
  });

  console.log('✅ Created guest user:', guestUser.id);

  console.log('\n🎉 Database seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Error during seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
