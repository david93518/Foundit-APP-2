import {
  Controller, Get, Post, Patch, Delete, Body, Param, Query,
  UseGuards, HttpCode, HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ItemsService } from './items.service';
import { CreateItemDto } from './dto/create-item.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { QueryItemDto } from './dto/query-item.dto';
import { toMobileItem } from './item-mobile.serializer';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { User } from '../common/entities/user.entity';
import { RateLimit } from '../common/abuse-limit.interceptor';

@ApiTags('物品')
@Controller('items')
export class ItemsController {
  constructor(private readonly itemsService: ItemsService) {}

  // App 登入前看不到任何物品；API 同樣要求登入，未登入者無法整批抓取刊登、照片與位置。
  @Get()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '取得物品列表（支援篩選）' })
  async findAll(@Query() query: QueryItemDto, @CurrentUser() user: User) {
    const { data, total, hasMore } = await this.itemsService.findAll(query);
    return { success: true, data: data.map((item) => toMobileItem(item, user.id)), total, hasMore };
  }

  @Get('stats')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '全平台統計（首頁榮譽帶 / 分類角標）' })
  async stats() {
    const data = await this.itemsService.getStats();
    return { success: true, data };
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '取得單一物品詳情' })
  async findOne(@Param('id') id: string, @CurrentUser() user: User) {
    const data = await this.itemsService.findOne(id, user.id);
    return { success: true, data: toMobileItem(data, user.id) };
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'item-create', limit: 20, windowMs: 60 * 60_000, by: 'user' })
  @ApiBearerAuth()
  @ApiOperation({ summary: '新增物品（遺失物或撿到物）' })
  async create(@Body() dto: CreateItemDto, @CurrentUser() user: User) {
    const data = await this.itemsService.create(dto, user);
    return { success: true, data: toMobileItem(data, user.id) };
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ name: 'item-update', limit: 60, windowMs: 60 * 60_000, by: 'user' })
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新物品資訊' })
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateItemDto,
    @CurrentUser() user: User,
  ) {
    const data = await this.itemsService.update(id, dto, user);
    return { success: true, data: toMobileItem(data, user.id) };
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: '刪除物品' })
  async remove(@Param('id') id: string, @CurrentUser() user: User) {
    await this.itemsService.remove(id, user);
    return { success: true, message: '已刪除' };
  }

  @Patch(':id/resolve')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: '標記物品已找到/已解決' })
  async resolve(@Param('id') id: string, @CurrentUser() user: User) {
    await this.itemsService.resolve(id, user);
    return { success: true, message: '已標記為找到' };
  }
}
