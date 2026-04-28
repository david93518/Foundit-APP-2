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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChatsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const chat_entity_1 = require("../common/entities/chat.entity");
const message_entity_1 = require("../common/entities/message.entity");
const item_entity_1 = require("../common/entities/item.entity");
let ChatsService = class ChatsService {
    chatRepo;
    msgRepo;
    itemRepo;
    constructor(chatRepo, msgRepo, itemRepo) {
        this.chatRepo = chatRepo;
        this.msgRepo = msgRepo;
        this.itemRepo = itemRepo;
    }
    async createOrGet(dto, requester) {
        const item = await this.itemRepo.findOne({
            where: { id: dto.item_id },
            relations: ['user'],
        });
        if (!item)
            throw new common_1.NotFoundException('物品不存在');
        if (item.userId === requester.id) {
            throw new common_1.BadRequestException('不能和自己的物品開啟聊天');
        }
        const existing = await this.chatRepo
            .createQueryBuilder('chat')
            .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: requester.id })
            .where('chat.item_id = :itemId', { itemId: dto.item_id })
            .getOne();
        if (existing)
            return this.loadChat(existing.id);
        const chat = this.chatRepo.create({ itemId: dto.item_id });
        chat.participants = [requester, item.user];
        const saved = await this.chatRepo.save(chat);
        await this.msgRepo.save(this.msgRepo.create({
            chatId: saved.id,
            senderId: requester.id,
            content: `${requester.name} 就「${item.title}」發起聯絡`,
            type: message_entity_1.MessageType.SYSTEM,
        }));
        return this.loadChat(saved.id);
    }
    async findAllForUser(userId) {
        const chats = await this.chatRepo
            .createQueryBuilder('chat')
            .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: userId })
            .leftJoinAndSelect('chat.participants', 'participant')
            .leftJoinAndSelect('chat.item', 'item')
            .orderBy('chat.updated_at', 'DESC')
            .getMany();
        if (chats.length === 0)
            return [];
        const chatIds = chats.map((c) => c.id);
        const [lastMsgs, unreadRows] = await Promise.all([
            this.msgRepo
                .createQueryBuilder('m')
                .where('m.chat_id IN (:...ids)', { ids: chatIds })
                .andWhere('m.created_at = (SELECT MAX(m2.created_at) FROM messages m2 WHERE m2.chat_id = m.chat_id)')
                .getMany(),
            this.msgRepo
                .createQueryBuilder('m')
                .select('m.chat_id', 'chat_id')
                .addSelect('COUNT(*)', 'count')
                .where('m.chat_id IN (:...ids)', { ids: chatIds })
                .andWhere('m.sender_id != :uid', { uid: userId })
                .andWhere('m.read_at IS NULL')
                .groupBy('m.chat_id')
                .getRawMany(),
        ]);
        const lastByChat = new Map();
        lastMsgs.forEach((m) => lastByChat.set(m.chatId, m));
        const unreadByChat = new Map();
        unreadRows.forEach((r) => unreadByChat.set(r.chat_id, Number(r.count)));
        return chats.map((c) => Object.assign(c, {
            unreadCount: unreadByChat.get(c.id) ?? 0,
            lastMessage: lastByChat.get(c.id) ?? null,
        }));
    }
    async unreadTotalForUser(userId) {
        const result = await this.msgRepo
            .createQueryBuilder('m')
            .innerJoin('chat_participants', 'cp', 'cp.chat_id = m.chat_id')
            .where('cp.user_id = :uid', { uid: userId })
            .andWhere('m.sender_id != :uid', { uid: userId })
            .andWhere('m.read_at IS NULL')
            .getCount();
        return result;
    }
    async getMessages(chatId, userId, page = 1, pageSize = 50) {
        await this.assertParticipant(chatId, userId);
        return this.msgRepo.find({
            where: { chatId },
            order: { createdAt: 'ASC' },
            skip: (page - 1) * pageSize,
            take: pageSize,
            relations: ['sender'],
        });
    }
    async sendMessage(chatId, dto, sender) {
        await this.assertParticipant(chatId, sender.id);
        const msg = this.msgRepo.create({
            chatId,
            senderId: sender.id,
            content: dto.content,
            type: dto.type ?? message_entity_1.MessageType.TEXT,
        });
        const saved = await this.msgRepo.save(msg);
        await this.chatRepo.update(chatId, { updatedAt: new Date() });
        saved.sender = sender;
        return saved;
    }
    async markRead(chatId, userId) {
        await this.assertParticipant(chatId, userId);
        await this.msgRepo
            .createQueryBuilder()
            .update(message_entity_1.Message)
            .set({ readAt: new Date() })
            .where('chat_id = :chatId AND sender_id != :userId AND read_at IS NULL', { chatId, userId })
            .execute();
    }
    async assertParticipant(chatId, userId) {
        const count = await this.chatRepo
            .createQueryBuilder('chat')
            .innerJoin('chat.participants', 'p', 'p.id = :uid', { uid: userId })
            .where('chat.id = :chatId', { chatId })
            .getCount();
        if (count === 0)
            throw new common_1.ForbiddenException('無權限存取此聊天室');
    }
    async loadChat(id) {
        const chat = await this.chatRepo.findOne({
            where: { id },
            relations: ['participants', 'item'],
        });
        if (!chat)
            throw new common_1.NotFoundException('聊天室不存在');
        const lastMsgs = await this.msgRepo.find({
            where: { chatId: id },
            order: { createdAt: 'DESC' },
            take: 1,
        });
        chat.messages = lastMsgs;
        return chat;
    }
};
exports.ChatsService = ChatsService;
exports.ChatsService = ChatsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(chat_entity_1.Chat)),
    __param(1, (0, typeorm_1.InjectRepository)(message_entity_1.Message)),
    __param(2, (0, typeorm_1.InjectRepository)(item_entity_1.Item)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], ChatsService);
//# sourceMappingURL=chats.service.js.map