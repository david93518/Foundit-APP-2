"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AiService = void 0;
const common_1 = require("@nestjs/common");
const items_service_1 = require("../items/items.service");
const item_entity_1 = require("../common/entities/item.entity");
let AiService = class AiService {
    itemsService;
    constructor(itemsService) {
        this.itemsService = itemsService;
    }
    async match(params) {
        let sourceItem = null;
        let keywords = [];
        if (params.itemId) {
            sourceItem = await this.itemsService.findOne(params.itemId);
            keywords = this.extractKeywords(sourceItem.title, sourceItem.description, sourceItem.category);
        }
        else if (params.keyword) {
            keywords = params.keyword.split(/[\s,，、]+/).filter(Boolean);
        }
        const candidates = await this.itemsService.findForMatch(params.itemId ?? '__none__', keywords);
        return candidates
            .map((item) => {
            const score = this.calculateScore(sourceItem, item, keywords);
            return { item, score, similarityPercent: Math.round(score * 100) };
        })
            .filter((r) => r.score > 0)
            .sort((a, b) => b.score - a.score)
            .slice(0, 10);
    }
    calculateScore(source, candidate, keywords) {
        let score = 0;
        if (source) {
            if (source.category === candidate.category)
                score += 0.3;
            if (source.color === candidate.color)
                score += 0.2;
            const isOpposite = (source.type === item_entity_1.ItemType.LOST && candidate.type === item_entity_1.ItemType.FOUND) ||
                (source.type === item_entity_1.ItemType.FOUND && candidate.type === item_entity_1.ItemType.LOST);
            if (isOpposite)
                score += 0.1;
            if (source.lostAt && candidate.lostAt) {
                const diffDays = Math.abs((new Date(source.lostAt).getTime() - new Date(candidate.lostAt).getTime()) / 86400000);
                if (diffDays <= 1)
                    score += 0.15;
                else if (diffDays <= 7)
                    score += 0.05;
            }
        }
        const text = `${candidate.title} ${candidate.description} ${candidate.category}`.toLowerCase();
        const hitCount = keywords.filter((kw) => text.includes(kw.toLowerCase())).length;
        if (keywords.length > 0)
            score += (hitCount / keywords.length) * 0.25;
        return Math.min(score, 1);
    }
    extractKeywords(...texts) {
        return texts
            .join(' ')
            .replace(/[^\w\u4e00-\u9fff]/g, ' ')
            .split(/\s+/)
            .filter((w) => w.length >= 2)
            .slice(0, 10);
    }
};
exports.AiService = AiService;
exports.AiService = AiService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [items_service_1.ItemsService])
], AiService);
//# sourceMappingURL=ai.service.js.map