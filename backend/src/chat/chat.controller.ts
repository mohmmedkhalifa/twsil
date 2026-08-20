import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ChatService, SendMessageDto } from './chat.service';

@Controller('chats')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Get('conversations')
  conversations(@CurrentUser() user: { id: string }) {
    return this.chat.conversations(user.id);
  }

  @Get(':conversationId/messages')
  messages(
    @CurrentUser() user: { id: string },
    @Param('conversationId') conversationId: string,
  ) {
    return this.chat.messagesForUser(user.id, conversationId);
  }

  @Get('unread-count')
  unreadCount(@CurrentUser() user: { id: string }) {
    return this.chat.unreadCount(user.id);
  }

  @Get('order/:orderId')
  byOrder(@CurrentUser() user: { id: string }, @Param('orderId') orderId: string) {
    return this.chat.conversationForUser(orderId, user.id);
  }

  @Post(':conversationId/messages')
  send(
    @CurrentUser() user: { id: string },
    @Param('conversationId') conversationId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.chat.send(user.id, conversationId, dto);
  }

  @Patch(':conversationId/read')
  markRead(@CurrentUser() user: { id: string }, @Param('conversationId') conversationId: string) {
    return this.chat.markRead(user.id, conversationId);
  }
}