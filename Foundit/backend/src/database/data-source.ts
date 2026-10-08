import 'reflect-metadata';
import { existsSync, readFileSync } from 'fs';
import { DataSource } from 'typeorm';
import { User } from '../common/entities/user.entity';
import { Item } from '../common/entities/item.entity';
import { Chat } from '../common/entities/chat.entity';
import { Message } from '../common/entities/message.entity';
import { Notification } from '../common/entities/notification.entity';
import { QrItem } from '../common/entities/qr-item.entity';
import { UserPoints } from '../common/entities/user-points.entity';
import { PointEvent } from '../common/entities/point-event.entity';
import { Report } from '../common/entities/report.entity';
import { Block } from '../common/entities/block.entity';
import { AdminAction } from '../common/entities/admin-action.entity';

if (existsSync('.env')) {
  for (const line of readFileSync('.env', 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;
    const index = trimmed.indexOf('=');
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim();
    if (key && process.env[key] == null) process.env[key] = value;
  }
}

const entities = [User, Item, Chat, Message, Notification, QrItem, UserPoints, PointEvent, Report, Block, AdminAction];
const migrationDir = __dirname.replace(/\\/g, '/');

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  database: process.env.DB_NAME ?? 'foundit',
  username: process.env.DB_USER ?? 'foundit_user',
  password: process.env.DB_PASS ?? 'foundit_pass',
  entities,
  migrations: [`${migrationDir}/migrations/*.js`, `${migrationDir}/migrations/*.ts`],
  synchronize: false,
});
