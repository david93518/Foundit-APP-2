import { Injectable } from '@nestjs/common';
import { ItemsService } from '../items/items.service';
import { Item, ItemType } from '../common/entities/item.entity';

export interface MatchResult {
  item: Item;
  score: number;
  similarityPercent: number;
}

/**
 * AI 配對服務（第一階段：關鍵字相似度配對）
 * 正式階段可替換為 CLIP / OpenAI embedding 向量比對。
 */
@Injectable()
export class AiService {
  constructor(private readonly itemsService: ItemsService) {}

  async match(params: {
    itemId?: string;
    imageUrl?: string;
    type?: ItemType;
    keyword?: string;
  }): Promise<MatchResult[]> {
    let sourceItem: Item | null = null;
    let keywords: string[] = [];

    if (params.itemId) {
      sourceItem = await this.itemsService.findOne(params.itemId);
      keywords = this.extractKeywords(sourceItem.title, sourceItem.description, sourceItem.category);
    } else if (params.keyword) {
      keywords = params.keyword.split(/[\s,，、]+/).filter(Boolean);
    }

    const candidates = await this.itemsService.findForMatch(
      params.itemId ?? null,
      keywords,
    );

    return candidates
      .map((item) => {
        const score = this.calculateScore(sourceItem, item, keywords);
        return { item, score, similarityPercent: Math.round(score * 100) };
      })
      .filter((r) => r.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 10);
  }

  private calculateScore(source: Item | null, candidate: Item, keywords: string[]): number {
    let score = 0;

    if (source) {
      if (source.category === candidate.category) score += 0.3;
      if (source.color === candidate.color) score += 0.2;
      // 對立類型加分（遺失物配撿到物）
      const isOpposite =
        (source.type === ItemType.LOST && candidate.type === ItemType.FOUND) ||
        (source.type === ItemType.FOUND && candidate.type === ItemType.LOST);
      if (isOpposite) score += 0.1;
      // 時間接近加分
      if (source.lostAt && candidate.lostAt) {
        const diffDays = Math.abs(
          (new Date(source.lostAt).getTime() - new Date(candidate.lostAt).getTime()) / 86400000,
        );
        if (diffDays <= 1) score += 0.15;
        else if (diffDays <= 7) score += 0.05;
      }
    }

    // 關鍵字命中
    const text = `${candidate.title} ${candidate.description} ${candidate.category}`.toLowerCase();
    const hitCount = keywords.filter((kw) => text.includes(kw.toLowerCase())).length;
    if (keywords.length > 0) score += (hitCount / keywords.length) * 0.25;

    return Math.min(score, 1);
  }

  private extractKeywords(...texts: string[]): string[] {
    return texts
      .join(' ')
      .replace(/[^\w\u4e00-\u9fff]/g, ' ')
      .split(/\s+/)
      .filter((w) => w.length >= 2)
      .slice(0, 10);
  }
}
