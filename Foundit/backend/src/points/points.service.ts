import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, MoreThan, Repository } from 'typeorm';
import { UserPoints } from '../common/entities/user-points.entity';
import { PointEvent, PointEventType } from '../common/entities/point-event.entity';

const POINT_VALUES: Record<PointEventType, number> = {
  [PointEventType.FOUND_ITEM]: 50,
  [PointEventType.MATCH_SUCCESS]: 100,
  [PointEventType.DAILY_LOGIN]: 5,
  [PointEventType.QR_SCAN]: 20,
  [PointEventType.REWARD_RECEIVED]: 0, // 動態設定
};

@Injectable()
export class PointsService {
  constructor(
    @InjectRepository(UserPoints) private readonly pointsRepo: Repository<UserPoints>,
    @InjectRepository(PointEvent) private readonly eventRepo: Repository<PointEvent>,
  ) {}

  async getPoints(userId: string): Promise<{ points: number; history: PointEvent[] }> {
    const userPoints = await this.getOrCreate(userId);
    const history = await this.eventRepo.find({
      where: { userPointsId: userPoints.id },
      order: { createdAt: 'DESC' },
      take: 50,
    });
    return { points: userPoints.points, history };
  }

  /** Serializes an account's awards and records the cause before incrementing its total. */
  async award(userId: string, type: PointEventType, reference: string, description: string, transaction?: EntityManager): Promise<boolean> {
    const apply = async (manager: EntityManager) => {
      await manager.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', ['points:' + userId]);
      if (type === PointEventType.QR_SCAN) {
        const [count] = await manager.query(`SELECT count(*)::int AS n FROM point_awards WHERE user_id=$1 AND kind=$2
          AND (created_at AT TIME ZONE 'Asia/Taipei')::date = (now() AT TIME ZONE 'Asia/Taipei')::date`, [userId,type]);
        if (count.n >= 5) return false;
      }
      const inserted = await manager.query(`INSERT INTO point_awards(user_id,kind,reference) VALUES($1,$2,$3)
        ON CONFLICT DO NOTHING RETURNING user_id`, [userId,type,reference]);
      if (!inserted.length) return false;
      const points = POINT_VALUES[type];
      const [total] = await manager.query(`INSERT INTO user_points(user_id,points) VALUES($1,$2)
        ON CONFLICT(user_id) DO UPDATE SET points=user_points.points+$2, updated_at=now() RETURNING id`, [userId,points]);
      await manager.query('INSERT INTO point_events(user_points_id,type,points,description) VALUES($1,$2,$3,$4)',
        [total.id,type,points,description]);
      return true;
    };
    return transaction ? apply(transaction) : this.pointsRepo.manager.transaction(apply);
  }

  async addPoints(
    userId: string,
    type: PointEventType,
    description: string,
    customPoints?: number,
  ): Promise<void> {
    const userPoints = await this.getOrCreate(userId);
    const pts = customPoints ?? POINT_VALUES[type] ?? 0;
    if (pts === 0) return;

    userPoints.points += pts;
    await this.pointsRepo.save(userPoints);

    await this.eventRepo.save(
      this.eventRepo.create({
        userPointsId: userPoints.id,
        type,
        points: pts,
        description,
      }),
    );
  }

  async getLeaderboard(limit = 20): Promise<UserPoints[]> {
    return this.pointsRepo.find({
      relations: ['user'],
      where: { points: MoreThan(0), user: { status: 'active' } },
      order: { points: 'DESC' },
      take: limit,
    });
  }

  private async getOrCreate(userId: string): Promise<UserPoints> {
    let up = await this.pointsRepo.findOne({ where: { userId } });
    if (!up) {
      up = await this.pointsRepo.save(this.pointsRepo.create({ userId, points: 0 }));
    }
    return up;
  }
}
