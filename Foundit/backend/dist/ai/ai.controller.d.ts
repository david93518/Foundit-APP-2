import { AiService } from './ai.service';
declare class AiMatchDto {
    item_id?: string;
    image_url?: string;
    keyword?: string;
}
export declare class AiController {
    private readonly aiService;
    constructor(aiService: AiService);
    match(dto: AiMatchDto): Promise<{
        success: boolean;
        data: {
            item: Record<string, unknown>;
            score: number;
            similarity_percent: number;
        }[];
    }>;
}
export {};
