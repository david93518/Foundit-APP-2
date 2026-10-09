import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThan, Repository } from 'typeorm';
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
