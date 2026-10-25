import { Logger, Module, OnModuleInit } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { join } from 'path';
import {
  ConversationEntity,
  FlowLoader,
  MockBrainAdapter,
  ProjectEntity,
  ProviderIngressEntity,
  StudioUiModule,
  VapiStudioModule,
} from '@guidify-ai/vapi-studio';
import { HealthController } from './health/health.controller';
import { ProjectSeedService } from './project/project-seed.service';
import { VapiController } from './vapi/vapi.controller';
import { AppConversationEntry } from './conversation/entry';
import { GreetNode } from './conversation/nodes/greet.node';
import { GoodbyeNode } from './conversation/nodes/goodbye.node';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      url: process.env.DATABASE_URL ?? 'postgres://studio:studio@postgres:5432/studio',
      entities: [
        ConversationEntity,
        ProviderIngressEntity,
        ProjectEntity,
      ],
      synchronize: true,
    }),
    StudioUiModule.forRoot(),
    VapiStudioModule.forRoot({
      entryPoint: AppConversationEntry,
      brainAdapter: MockBrainAdapter,
      limits: {
        endMessage: "We've reached the end of our time — thanks for calling. Goodbye.",
      },
      nodes: [
        { className: 'GreetNode', useClass: GreetNode },
        { className: 'GoodbyeNode', useClass: GoodbyeNode },
      ],
    }),
  ],
  controllers: [HealthController, VapiController],
  providers: [ProjectSeedService],
})
export class AppModule implements OnModuleInit {
  private readonly logger = new Logger(AppModule.name);

  constructor(private readonly flowLoader: FlowLoader) {}

  async onModuleInit(): Promise<void> {
    const configDir = process.env.CONFIG_DIR ?? join(process.cwd(), 'config');
    this.flowLoader.loadFromFile(join(configDir, 'flow.yaml'));
    this.logger.log('Loaded config/flow.yaml');
  }
}
